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

module engine.scene.scenenode;

private
{
    import std.algorithm;
    
    import derelict.opengl.gl;
    
    import dlib.math.utils;
    import dlib.math.vector;
    import dlib.math.matrix4x4;
    import dlib.geometry.sphere;
    
    import engine.core.drawable;
    import engine.core.modifier;
    import engine.graphics.material;
    import engine.physics.rigidbody;
}

class SceneNode: Drawable, Modifier
{
    SceneNode parent = null;
    SceneNode[] children;
    Modifier[] modifiers;

    Material material;
    
    Vector3f position;
    Vector3f rotation;
    Vector3f scaling;
    Vector3f positionPrevious;
    
    bool visible = true;
    
    Matrix4x4f localMatrix;
    Matrix4x4f* localMatrixPtr;

    RigidBody rigidBody = null;
    
    this(SceneNode par = null)
    {
        parent = par;
        if (parent !is null)
            parent.addChild(this);
            
        position = Vector3f(0.0f, 0.0f, 0.0f);
        rotation = Vector3f(0.0f, 0.0f, 0.0f);
        scaling = Vector3f(1.0f, 1.0f, 1.0f);
        positionPrevious = position;
        
        localMatrix = identityMatrix4x4f();
        localMatrixPtr = &localMatrix;
    }
    
    void addChild(SceneNode child)
    {
        children ~= child;
    }
    
    void removeChild(SceneNode child)
    {
        int index = getChildIndex(child);
        if (index >= 0)
            children = children.remove(index);
    }
    
    int getChildIndex(SceneNode child)
    {
        foreach(i, node; children)
        {
            if (node == child)
                return i;
        }
        return -1;
    }

    void setMaterial(Material m)
    {
        material = m;
    }
    
    @property Vector3f velocity()
    {
        return position - positionPrevious;
    }
    
    @property float speed()
    {
        return velocity.length;
    }
    
    @property bool isMoving()
    {
        return (!velocity.isZero);
    }
    
    @property Vector3f absolutePosition()
    {
        if (parent is null)
            return position;
        else
            return parent.absolutePosition + position;
    }
    
    @property Matrix4x4f absoluteMatrix()
    {
        if (parent !is null)
            return parent.absoluteMatrix * (*localMatrixPtr);
        else
            return *localMatrixPtr;
    }
    
    void translate(Vector3f vec)
    {
        position += vec;
    }
    
    void move(float speed)
    {
        position += localMatrix.forward * speed;
    }
    
    void strafe(float speed)
    {
        position += localMatrix.right * speed;
    }
    
    void lift(float speed)
    {
        position += localMatrix.up * speed;
    }
    
    void moveToPoint(Vector3f pt, float speed)
    {
        Vector3f dir = pt - position;
        dir.normalize();

        float dist = distance(position, pt);
        if (dist != 0.0f)
        {
            if (dist >= speed)
            {
                position += dir * speed;
            }
            else
            {
                position += dir * dist;
            }
        }
    }
    
    void rotate(Vector3f vec)
    {
        rotation += vec;
    }

    void pitch(float angle)
    {
        rotation.x += angle;
    }

    void turn(float angle)
    {
        rotation.y += angle;
    }

    void roll(float angle)
    {
        rotation.z += angle;
    }
    
    void scale(Vector3f factor)
    {
        scaling += factor;
    }
    
    void bind(double delta)
    {
        if (rigidBody is null)
        {
            localMatrix = translationMatrix(position);
            positionPrevious = position;

            localMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
            localMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
            localMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));

            localMatrix *= scaleMatrix(scaling);
        }
        else 
        {
            if (rigidBody.type == BodyType.Dynamic)
            {
                localMatrix = rigidBody.geometry.transformation;

                if (rigidBody.disableRotation)
                {
                    localMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
                    localMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
                    localMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));
                }
            }
            else
            {
                localMatrix = translationMatrix(position);

                rigidBody.position = position;

                localMatrix *= rotationMatrix(Axis.x, degtorad(rotation.x));
                localMatrix *= rotationMatrix(Axis.y, degtorad(rotation.y));
                localMatrix *= rotationMatrix(Axis.z, degtorad(rotation.z));

                localMatrix *= scaleMatrix(scaling);

                positionPrevious = position;
            }
        }

        glPushMatrix();
        glMultMatrixf(localMatrixPtr.arrayof.ptr);
    }
    
    void unbind()
    {
        glPopMatrix();
    }
    
    void draw(double delta)
    {
        bind(delta);
        
        foreach(child; children)
        {
            child.draw(delta);
        }

        if (material)
            material.bind(delta);
        
        foreach(m; modifiers)
            m.bind(delta);

        render(delta);

        foreach(m; modifiers)
            m.unbind();

        if (material)
            material.unbind();
        
        unbind();
    }
    
    void render(double delta) // override me
    {
    }
    
    void free()
    {
        if (children.length > 0)
        {
            clean();
            if (parent !is null)
                parent.removeChild(this);
            parent = null;
        }
    }

    void clean() // override me
    {
    }

    @property Sphere boundingSphere() // override me
    {
        return Sphere(absolutePosition, scaling.x);
    }
}

