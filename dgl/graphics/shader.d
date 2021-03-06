/*
Copyright (c) 2015-2016 Timur Gafarov

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

module dgl.graphics.shader;

import std.stdio;
import std.string;
import std.conv;
import dlib.core.memory;
import dlib.container.dict;
import dlib.math.vector;
import dlib.math.matrix;
import dgl.core.api;
import dgl.core.event;
import dgl.core.interfaces;
import dgl.graphics.state;
import dgl.graphics.material;
import dgl.graphics.camera;

class Shader
{
    protected:
    bool _supported;
    
    private:
    GLenum shaderVert;
    GLenum shaderFrag;
    GLenum shaderProg;
    
    GLint loc_dgl_Texture0;
    GLint loc_dgl_Texture1;
    GLint loc_dgl_Texture2;
    GLint loc_dgl_Texture3;
    GLint loc_dgl_Texture4;
    GLint loc_dgl_Texture5;
    GLint loc_dgl_Texture6;
    GLint loc_dgl_Texture7;
    
    GLint loc_dgl_WindowSize;
    GLint loc_dgl_ShadowMapSize;
    GLint loc_dgl_Shadeless;
    GLint loc_dgl_Textures;
    GLint loc_dgl_NormalMapping;
    GLint loc_dgl_ParallaxMapping;
    GLint loc_dgl_GlowMap;
    GLint loc_dgl_Fog;
    GLint loc_dgl_Shadow;
    GLint loc_dgl_Matcap;
    GLint loc_dgl_EnvMapping;
    
    GLint loc_dgl_Specularity;
    GLint loc_dgl_Roughness;
    GLint loc_dgl_Metallic;
    GLint loc_dgl_PBRMapping;
    
    GLint loc_dgl_ShadowType;
    
    GLint loc_dgl_ViewMatrix;
    GLint loc_dgl_InvViewMatrix;
    
    Matrix4x4f viewMatrix;
    Matrix4x4f invViewMatrix;

    public:
    this(string vertexProgram, string fragmentProgram)
    {
        _supported = supported;

        if (_supported)
        {
            shaderProg = glCreateProgramObjectARB();
            shaderVert = glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
            shaderFrag = glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);

            int len;
            char* srcptr;

            len = cast(int)vertexProgram.length;
            srcptr = cast(char*)vertexProgram.ptr;
            glShaderSourceARB(shaderVert, 1, &srcptr, &len);

            len = cast(int)fragmentProgram.length;
            srcptr = cast(char*)fragmentProgram.ptr;
            glShaderSourceARB(shaderFrag, 1, &srcptr, &len);

            glCompileShaderARB(shaderVert);
            glCompileShaderARB(shaderFrag);
            glAttachObjectARB(shaderProg, shaderVert);
            glAttachObjectARB(shaderProg, shaderFrag);
            glLinkProgramARB(shaderProg);

            char[1000] infobuffer = 0;
            int infobufferlen = 0;

            glGetInfoLogARB(shaderVert, 999, &infobufferlen, infobuffer.ptr);
            if (infobuffer[0] != 0)
                writefln("GLSL: error in vertex shader:\n%s\n", infobuffer.ptr.to!string);

            glGetInfoLogARB(shaderFrag, 999, &infobufferlen, infobuffer.ptr);
            if (infobuffer[0] != 0)
                writefln("GLSL: error in fragment shader:\n%s\n", infobuffer.ptr.to!string);
                
            loc_dgl_Texture0 = glGetUniformLocationARB(shaderProg, "dgl_Texture0");
            loc_dgl_Texture1 = glGetUniformLocationARB(shaderProg, "dgl_Texture1");
            loc_dgl_Texture2 = glGetUniformLocationARB(shaderProg, "dgl_Texture2");
            loc_dgl_Texture3 = glGetUniformLocationARB(shaderProg, "dgl_Texture3");
            loc_dgl_Texture4 = glGetUniformLocationARB(shaderProg, "dgl_Texture4");
            loc_dgl_Texture5 = glGetUniformLocationARB(shaderProg, "dgl_Texture5");
            loc_dgl_Texture6 = glGetUniformLocationARB(shaderProg, "dgl_Texture6");
            loc_dgl_Texture7 = glGetUniformLocationARB(shaderProg, "dgl_Texture7");
            
            loc_dgl_WindowSize = glGetUniformLocationARB(shaderProg, "dgl_WindowSize");
            
            loc_dgl_ShadowMapSize = glGetUniformLocationARB(shaderProg, "dgl_ShadowMapSize");

            loc_dgl_Shadeless = glGetUniformLocation(shaderProg, "dgl_Shadeless");
            loc_dgl_Textures = glGetUniformLocation(shaderProg, "dgl_Textures");
            loc_dgl_NormalMapping = glGetUniformLocation(shaderProg, "dgl_NormalMapping");
            loc_dgl_ParallaxMapping = glGetUniformLocation(shaderProg, "dgl_ParallaxMapping");
            loc_dgl_GlowMap = glGetUniformLocation(shaderProg, "dgl_GlowMap");
            loc_dgl_Fog = glGetUniformLocation(shaderProg, "dgl_Fog");
            loc_dgl_Shadow = glGetUniformLocation(shaderProg, "dgl_Shadow");
            loc_dgl_Matcap = glGetUniformLocation(shaderProg, "dgl_Matcap");
            loc_dgl_EnvMapping = glGetUniformLocation(shaderProg, "dgl_EnvMapping");
            loc_dgl_Specularity = glGetUniformLocation(shaderProg, "dgl_Specularity");
            loc_dgl_Roughness = glGetUniformLocation(shaderProg, "dgl_Roughness");
            loc_dgl_Metallic = glGetUniformLocation(shaderProg, "dgl_Metallic");
            loc_dgl_PBRMapping = glGetUniformLocation(shaderProg, "dgl_PBRMapping");
            
            loc_dgl_ShadowType = glGetUniformLocation(shaderProg, "dgl_ShadowType");
            
            loc_dgl_ViewMatrix = glGetUniformLocation(shaderProg, "dgl_ViewMatrix");
            loc_dgl_InvViewMatrix = glGetUniformLocation(shaderProg, "dgl_InvViewMatrix");
        }
        
        viewMatrix = Matrix4x4f.identity;
        invViewMatrix = Matrix4x4f.identity;
    }

    bool supported()
    {
        return DerelictGL.isExtensionSupported("GL_ARB_shading_language_100");
    }
    
    void setViewMatrix(Camera cam)
    {
        viewMatrix = cam.getInvTransformation();
        invViewMatrix = cam.getTransformation();
    }

    void bind(Material mat)
    {
        if (_supported)
        {
            glUseProgramObjectARB(shaderProg);

            glUniform1iARB(loc_dgl_Texture0, 0);
            glUniform1iARB(loc_dgl_Texture1, 1);
            glUniform1iARB(loc_dgl_Texture2, 2);
            glUniform1iARB(loc_dgl_Texture3, 3);
            glUniform1iARB(loc_dgl_Texture4, 4);
            glUniform1iARB(loc_dgl_Texture5, 5);
            glUniform1iARB(loc_dgl_Texture6, 6);
            glUniform1iARB(loc_dgl_Texture7, 7);
            
            glUniform2fARB(loc_dgl_WindowSize, PipelineState.viewportWidth, PipelineState.viewportHeight);
            glUniform1fARB(loc_dgl_ShadowMapSize, PipelineState.shadowMapSize);
            
            bool textureEnabled = false;
            bool bumpEnabled = false;
            bool parallaxEnabled = false;
            bool glowMapEnabled = false;
            bool fogEnabled = mat.useFog;
            bool envMapping = false;
            bool pbrMapping = false;

            if (mat.useTextures && mat.textures[0])
                textureEnabled = true;

            if (mat.useTextures && mat.textures[1] && mat.bump)
            {
                bumpEnabled = true;
                if (mat.textures[1].format == GL_RGBA || mat.textures[1].format == GL_LUMINANCE_ALPHA)
                    if (mat.parallax)
                        parallaxEnabled = true;
            }
              
            if (mat.useTextures && mat.textures[2] && mat.glowMap)
                glowMapEnabled = true;
            
            if (mat.useTextures && mat.textures[3])
                pbrMapping = true;
                
            if (mat.useTextures && mat.textures[4])
                envMapping = true;

            glUniform1i(loc_dgl_Shadeless, mat.shadeless);
            glUniform1i(loc_dgl_Textures, textureEnabled);
            glUniform1i(loc_dgl_NormalMapping, bumpEnabled);
            glUniform1i(loc_dgl_ParallaxMapping, parallaxEnabled);
            glUniform1i(loc_dgl_GlowMap, glowMapEnabled);
            glUniform1i(loc_dgl_Fog, fogEnabled);
            glUniform1i(loc_dgl_Shadow, mat.receiveShadows);
            glUniform1i(loc_dgl_Matcap, mat.matcap);
            glUniform1i(loc_dgl_EnvMapping, envMapping);
            glUniform1f(loc_dgl_Specularity, mat.specularity);
            glUniform1f(loc_dgl_Roughness, mat.roughness);
            glUniform1f(loc_dgl_Metallic, mat.metallic);
            glUniform1f(loc_dgl_PBRMapping, pbrMapping);
            
            glUniform1i(loc_dgl_ShadowType, cast(int)mat.shadowType);
            
            glUniformMatrix4fv(loc_dgl_ViewMatrix, 1, 0, viewMatrix.arrayof.ptr);
            glUniformMatrix4fv(loc_dgl_InvViewMatrix, 1, 0, invViewMatrix.arrayof.ptr);
        }
    }

    void unbind()
    {
        if (_supported)
        {
            glUseProgramObjectARB(0);
        }
    }

    ~this()
    {
        unbind();
    }
}
