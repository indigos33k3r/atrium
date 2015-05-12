﻿/*
Copyright (c) 2015 Timur Gafarov 

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

module dgl.graphics.lightmanager;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.math.vector;
import dlib.image.color;
import dlib.container.array;

import dgl.core.interfaces;
import dgl.graphics.object3d;

public import dgl.graphics.light;

class LightManager: Modifier3D, Drawable
{
    DynamicArray!Light lights;
    uint maxLightsPerObject = 4;
    bool lightsVisible = false;
    bool lightsOn = true;

    Light addLight(Light light)
    {
        lights.append(light);
        return light;
    }
    
    Light addPointLight(Vector3f position)
    {
        Light light = pointLight(
            position, 
            Color4f(1.0f, 1.0f, 1.0f, 1.0f), 
            Color4f(0.1f, 0.1f, 0.1f, 1.0f));
        lights.append(light);
        return light;
    }

    void bind(Object3D obj, double dt)
    {
        glEnable(GL_LIGHTING);
        apply(obj.getPosition);
    }

    void unbind(Object3D obj)
    {
        foreach(i; 0..maxLightsPerObject)
            glDisable(GL_LIGHT0 + i); 
        glDisable(GL_LIGHTING);
    }

    void calcBrightness(Light light, Vector3f objPos)
    {
        if (!light.enabled && !light.forceOn)
        {
            light.brightness = 0.0f;
        }
        else
        {
            Vector3f d = (light.position.xyz - objPos);
            float quadraticAttenuation = d.lengthsqr;
            light.brightness = 1.0f / quadraticAttenuation;
        }
    }

    void sortLights()
    {
        size_t j = 0;
        Light tmp;
        
        auto ldata = lights.data;

        foreach(i, v; ldata)
        {
            j = i;
            size_t k = i;

            while (k < ldata.length)
            {
                float b1 = ldata[j].brightness;
                float b2 = ldata[k].brightness;
                if (b2 > b1)
                    j = k;
                k++;
            }

            tmp = ldata[i];
            ldata[i] = ldata[j];
            ldata[j] = tmp;
        }
    }

    void apply(Vector3f objPos)
    {
        auto ldata = lights.data;
    
        foreach(light; ldata)
            if (lightsOn || light.forceOn)
                calcBrightness(light, objPos);

        sortLights();

        foreach(i; 0..maxLightsPerObject)
        if (i < lights.length)
        {
            auto light = ldata[i];
            if (light.enabled && (lightsOn || light.forceOn))
            {
                glEnable(GL_LIGHT0 + i);
                glLightfv(GL_LIGHT0 + i, GL_POSITION, light.position.arrayof.ptr);
				glLightfv(GL_LIGHT0 + i, GL_SPECULAR, light.diffuseColor.arrayof.ptr);
                glLightfv(GL_LIGHT0 + i, GL_DIFFUSE, light.diffuseColor.arrayof.ptr);
                glLightfv(GL_LIGHT0 + i, GL_AMBIENT, light.ambientColor.arrayof.ptr);
                glLightf( GL_LIGHT0 + i, GL_CONSTANT_ATTENUATION, light.constantAttenuation);
                glLightf( GL_LIGHT0 + i, GL_LINEAR_ATTENUATION, light.linearAttenuation);
                glLightf( GL_LIGHT0 + i, GL_QUADRATIC_ATTENUATION, light.quadraticAttenuation);
            }
			else
			{
			    Vector4f p = Vector4f(0, 0, 0, 2);
			    glLightfv(GL_LIGHT0 + i, GL_POSITION, p.arrayof.ptr);
			}
        }      
    }

    void unapply()
    {
        foreach(i; 0..maxLightsPerObject)
            glDisable(GL_LIGHT0 + i); 
    }
    
    void draw(double dt)
    {
        // Draw lights
        if (lightsVisible)
        {
            glPointSize(5.0f);
            foreach(light; lights.data)
            if (light.debugDraw)
            {
                glColor4fv(light.diffuseColor.arrayof.ptr);
                glBegin(GL_POINTS);
                glVertex3fv(light.position.arrayof.ptr);
                glEnd();
            }
            glPointSize(1.0f);
        }
    }

    void free()
    {
        foreach(light; lights.data)
            light.free();
        lights.free();
        
        Delete(this);
    }
    
    mixin ManualModeImpl;
}