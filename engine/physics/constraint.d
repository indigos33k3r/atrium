/*
Copyright (c) 2013 Timur Gafarov 

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module engine.physics.constraint;

import std.math;
import dlib.math.vector;
import dlib.math.matrix3x3;
import dlib.math.quaternion;
import engine.physics.rigidbody;

/*
 * TODO:
 * - move iterative solving routine from constraint classes to World
 * - expose prepare and iteration methods in Constraint class
 */

abstract class Constraint
{
    RigidBody body1;
    RigidBody body2;
    
    void solve(double delta);
}

/*
 * The ball-socket constraint, also known as point to point constraint, 
 * limits the translation so that the local anchor points of two rigid bodies 
 * match in world space.
 */
class BallConstraint: Constraint
{
    Vector3f localAnchor1, localAnchor2;
    Vector3f r1, r2;

    Vector3f[4] jacobian; 
   
    float accumulatedImpulse = 0.0f;
    
    float biasFactor = 1.0f;
    float softness = 0.0f;
    
    int iterations = 10;
    
    float softnessOverDt;
    float effectiveMass;
    float bias;

    this(RigidBody body1, RigidBody body2, Vector3f anchor1, Vector3f anchor2)
    {
        this.body1 = body1;
        this.body2 = body2;
        
        localAnchor1 = anchor1;
        localAnchor2 = anchor2;
    }
    
    void prepare(double delta)
    {
        Vector3f r1 = body1.orientation.rotate(localAnchor1);
        Vector3f r2 = body2.orientation.rotate(localAnchor2);

        Vector3f p1, p2, dp;
        p1 = body1.position + r1;
        p2 = body2.position + r2;

        dp = p2 - p1;

        float deltaLength = dp.length;
        Vector3f n = dp.normalized;

        jacobian[0] = -n;
        jacobian[1] = -cross(r1, n);
        jacobian[2] = n;
        jacobian[3] = cross(r2, n);

        effectiveMass = 
            body1.invMass + 
            body2.invMass +
            dot(jacobian[1] * body1.invInertiaMoment, jacobian[1]) +
            dot(jacobian[3] * body2.invInertiaMoment, jacobian[3]);

        softnessOverDt = softness / delta;
        effectiveMass += softnessOverDt;
        effectiveMass = 1.0f / effectiveMass;

        bias = deltaLength * biasFactor * (1.0f / delta);

        if (!body1.isStatic)
        {
            body1.linearVelocity += body1.invMass * accumulatedImpulse * jacobian[0];
            body1.angularVelocity += accumulatedImpulse * jacobian[1] * body1.invInertiaMoment;
        }

        if (!body2.isStatic)
        {
            body2.linearVelocity += body2.invMass * accumulatedImpulse * jacobian[2];
            body2.angularVelocity += accumulatedImpulse * jacobian[3] * body2.invInertiaMoment;
        }
    }
    
    void iteration()
    {
        float jv =
            dot(body1.linearVelocity, jacobian[0]) +
            dot(body1.angularVelocity, jacobian[1]) +
            dot(body2.linearVelocity, jacobian[2]) +
            dot(body2.angularVelocity, jacobian[3]);

        float softnessScalar = accumulatedImpulse * softnessOverDt;
        float lambda = -effectiveMass * (jv + bias + softnessScalar);

        accumulatedImpulse += lambda;

        if (!body1.isStatic)
        {
            body1.linearVelocity += body1.invMass * lambda * jacobian[0];
            body1.angularVelocity += lambda * jacobian[1] * body1.invInertiaMoment;
        }

        if (!body2.isStatic)
        {
            body2.linearVelocity += body2.invMass * lambda * jacobian[2];
            body2.angularVelocity += lambda * jacobian[3] * body2.invInertiaMoment;
        }
    }
    
    override void solve(double delta)
    {
        for (int i = -1; i < iterations; i++)
        {
            if (i == -1)
                prepare(delta);
            else iteration();
        }
    }
}

/*
 * Constraints a point on a body to be fixed on a line
 * which is fixed on another body.
 */
class SliderConstraint: Constraint
{
    Vector3f lineNormal;

    Vector3f localAnchor1, localAnchor2;
    Vector3f r1, r2;

    Vector3f[4] jacobian; 
   
    float accumulatedImpulse = 0.0f;
    
    float biasFactor = 1.0f;
    float softness = 0.0f;
    
    int iterations = 10;
    
    float softnessOverDt;
    float effectiveMass;
    float bias;

    this(RigidBody body1, RigidBody body2, Vector3f lineStartPointBody1, Vector3f pointBody2)
    {
        this.body1 = body1;
        this.body2 = body2;
        
        localAnchor1 = lineStartPointBody1;
        localAnchor2 = pointBody2;

        lineNormal = (lineStartPointBody1 + body1.position - 
                      pointBody2 + body2.position).normalized;
    }

    void prepare(double delta)
    {
        Vector3f r1 = body1.orientation.rotate(localAnchor1);
        Vector3f r2 = body2.orientation.rotate(localAnchor2);

        Vector3f p1, p2, dp;
        p1 = body1.position + r1;
        p2 = body2.position + r2;

        dp = p2 - p1;

        Vector3f l = body1.orientation.rotate(lineNormal);

        Vector3f t = cross((p1 - p2), l);
        if (t.lengthsqr != 0.0f)
            t.normalize();
        t = cross(t, l);

        jacobian[0] = t;
        jacobian[1] = cross((r1 + p2 - p1), t);
        jacobian[2] = -t;
        jacobian[3] = -cross(r2, t);

        effectiveMass = 
            body1.invMass + 
            body2.invMass +
            dot(jacobian[1] * body1.invInertiaMoment, jacobian[1]) +
            dot(jacobian[3] * body2.invInertiaMoment, jacobian[3]);

        softnessOverDt = softness / delta;
        effectiveMass += softnessOverDt;

        if (effectiveMass != 0)
            effectiveMass = 1.0f / effectiveMass;

        bias = -cross(l, (p2 - p1)).length * biasFactor * (1.0f / delta);

        if (!body1.isStatic)
        {
            body1.linearVelocity += body1.invMass * accumulatedImpulse * jacobian[0];
            body1.angularVelocity += accumulatedImpulse * jacobian[1] * body1.invInertiaMoment;
        }

        if (!body2.isStatic)
        {
            body2.linearVelocity += body2.invMass * accumulatedImpulse * jacobian[2];
            body2.angularVelocity += accumulatedImpulse * jacobian[3] * body2.invInertiaMoment;
        }
    }

    void iteration()
    {
        float jv =
            dot(body1.linearVelocity, jacobian[0]) +
            dot(body1.angularVelocity, jacobian[1]) +
            dot(body2.linearVelocity, jacobian[2]) +
            dot(body2.angularVelocity, jacobian[3]);

        float softnessScalar = accumulatedImpulse * softnessOverDt;
        float lambda = -effectiveMass * (jv + bias + softnessScalar);

        accumulatedImpulse += lambda;

        if (!body1.isStatic)
        {
            body1.linearVelocity += body1.invMass * lambda * jacobian[0];
            body1.angularVelocity += lambda * jacobian[1] * body1.invInertiaMoment;
        }

        if (!body2.isStatic)
        {
            body2.linearVelocity += body2.invMass * lambda * jacobian[2];
            body2.angularVelocity += lambda * jacobian[3] * body2.invInertiaMoment;
        }
    }

    override void solve(double delta)
    {
        for (int i = -1; i < iterations; i++)
        {
            if (i == -1)
                prepare(delta);
            else iteration();
        }
    }
}

/*
 * The AngleConstraint constraints two bodies to always have the same relative
 * orientation to each other.
 * Warning: unstable!
 */
class FixedAngleConstraint: Constraint
{
    Vector3f accumulatedImpulse;

    Matrix3x3f initialOrientation1, initialOrientation2;
    
    float biasFactor = 0.05f;
    float softness = 0.0f;
    
    int iterations = 10;
    
    float softnessOverDt;
    float effectiveMass;
    Vector3f bias;

    this(RigidBody body1, RigidBody body2)
    {
        this.body1 = body1;
        this.body2 = body2;

        initialOrientation1 = body1.orientation.toMatrix3x3;
        initialOrientation2 = body2.orientation.toMatrix3x3;

        accumulatedImpulse = Vector3f(0.0f, 0.0f, 0.0f);
    }

    void prepare(double delta)
    {
        effectiveMass = body1.invInertiaMoment + body2.invInertiaMoment;

        softnessOverDt = softness / delta;
        effectiveMass += softnessOverDt;

        if (effectiveMass != 0)
            effectiveMass = 1.0f / effectiveMass;

        Matrix3x3f orientationDifference;
        orientationDifference = initialOrientation1 * initialOrientation2;
        orientationDifference = orientationDifference.transposed();

        Matrix3x3f q = orientationDifference * body2.orientation.toMatrix3x3.inverse * body1.orientation.toMatrix3x3;

        float x = q.m32 - q.m23;
        float y = q.m13 - q.m31;
        float z = q.m21 - q.m12;

        float r = sqrt(x * x + y * y + z * z);
        float t = q.m11 + q.m22 + q.m33;

        float angle = atan2(r, t - 1.0f);
        Vector3f axis = Vector3f(x, y, z) * angle;
        if (r != 0.0f)
            axis = axis * (1.0f / r);

        bias = axis * biasFactor * (-1.0f / delta);

        if (!body1.isStatic) 
            body1.angularVelocity += accumulatedImpulse * body1.invInertiaMoment;

        if (!body2.isStatic)
            body2.angularVelocity += -accumulatedImpulse * body2.invInertiaMoment;
    }

    void iteration()
    {
        Vector3f jv = body1.angularVelocity - body2.angularVelocity;
        Vector3f softnessVector = accumulatedImpulse * softnessOverDt;

        Vector3f lambda = -(jv + bias + softnessVector) * effectiveMass;

        accumulatedImpulse += lambda;

        if (!body1.isStatic)
            body1.angularVelocity += lambda * body1.invInertiaMoment;

        if (!body2.isStatic)
            body2.angularVelocity += -lambda * body2.invInertiaMoment;
    }

    override void solve(double delta)
    {
        for (int i = -1; i < iterations; i++)
        {
            if (i == -1)
                prepare(delta);
            else iteration();
        }
    }
}


