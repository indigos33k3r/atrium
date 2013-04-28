/*
Copyright (c) 2011-2013 Timur Gafarov 

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

module dlib.image.image;

private
{
    import std.conv;
    import dlib.math.vector;
    import dlib.image.color;
}

enum PixelFormat
{
    L8,
    LA8,
    RGB8,
    RGBA8,
    L16,
    LA16,
    RGB16,
    RGBA16
}

interface SuperImage
{
    @property uint width();
    @property uint height();
    @property uint bitDepth();
    @property uint channels();
    @property uint pixelSize();
    @property PixelFormat pixelFormat();
    @property ref ubyte[] data();

    @property SuperImage dup();

    ColorRGBA opIndex(int x, int y);
    ColorRGBA opIndexAssign(ColorRGBA c, int x, int y);

    SuperImage createSameFormat(uint w, uint h);
}

class Image(PixelFormat fmt): SuperImage
{
    public:

    @property uint width()
    {
        return _width;
    }

    @property uint height()
    {
        return _height;
    }

    @property uint bitDepth()
    {
        return _bitDepth;
    }

    @property uint channels()
    {
        return _channels;
    }

    @property uint pixelSize()
    {
        return _pixelSize;
    }

    @property PixelFormat pixelFormat()
    {
        return fmt;
    }

    @property ref ubyte[] data()
    {
        return _data;
    }

    @property Image!(fmt) dup()
    {
        auto res = new Image!(fmt)(_width, _height);
        res.data = _data.dup;
        return res;
    }

    SuperImage createSameFormat(uint w, uint h)
    {
        return new Image!(fmt)(w, h);
    }

    this(uint w, uint h)
    {
        _width = w;
        _height = h;

        _bitDepth = [
            PixelFormat.L8:     8, PixelFormat.LA8:     8,  
            PixelFormat.RGB8:   8, PixelFormat.RGBA8:   8,
            PixelFormat.L16:   16, PixelFormat.LA16:   16, 
            PixelFormat.RGB16: 16, PixelFormat.RGBA16: 16
        ][fmt];

        _channels = [
            PixelFormat.L8:    1, PixelFormat.LA8:    2,
            PixelFormat.RGB8:  3, PixelFormat.RGBA8:  4,
            PixelFormat.L16:   1, PixelFormat.LA16:   2,  
            PixelFormat.RGB16: 3, PixelFormat.RGBA16: 4
        ][fmt];

        _pixelSize = (_bitDepth / 8) * _channels;
        _data = new ubyte[_width * _height * _pixelSize];
    }

    ColorRGBA opIndex(int x, int y)
    {
        while(x >= width) x = width-1;
        while(y >= height) y = height-1;
        while(x < 0) x = 0;
        while(y < 0) y = 0;

        auto index = (y * _width + x) * _pixelSize;

        static if (fmt == PixelFormat.L8)
        {
            auto v = _data[index];
            return ColorRGBA(v, v, v);
        }
        else if (fmt == PixelFormat.LA8)
        {
            auto v = _data[index];
            return ColorRGBA(v, v, v, data[index+1]);
        }
        else if (fmt == PixelFormat.RGB8)
        {
            return ColorRGBA(_data[index], _data[index+1], _data[index+2]);
        }
        else if (fmt == PixelFormat.RGBA8)
        {
            return ColorRGBA(_data[index], _data[index+1], _data[index+2], _data[index+3]);
        }
        else if (fmt == PixelFormat.L16)
        {
            ushort v = _data[index] << 8 | _data[index+1];
            return ColorRGBA(v, v, v);
        }
        else if (fmt == PixelFormat.LA16)
        {
            ushort v = _data[index]   << 8 | _data[index+1];
            ushort a = _data[index+2] << 8 | _data[index+3];
            return ColorRGBA(v, v, v, a);
        }
        else if (fmt == PixelFormat.RGB16)
        {
            ushort r = _data[index]   << 8 | _data[index+1];
            ushort g = _data[index+2] << 8 | _data[index+3];
            ushort b = _data[index+4] << 8 | _data[index+5];
            return ColorRGBA(r, g, b);
        }
        else if (fmt == PixelFormat.RGBA16)
        {
            ushort r = _data[index]   << 8 | _data[index+1];
            ushort g = _data[index+2] << 8 | _data[index+3];
            ushort b = _data[index+4] << 8 | _data[index+5];
            ushort a = _data[index+6] << 8 | _data[index+7];
            return ColorRGBA(r, g, b, a);
        }
        else
        {
            assert (0, "Image.opIndex is not implemented for PixelFormat." ~ to!string(fmt));
        }
    }

    ColorRGBA opIndexAssign(ColorRGBA c, int x, int y)
    {
        while(x >= width) x = width-1;
        while(y >= height) y = height-1;
        while(x < 0) x = 0;
        while(y < 0) y = 0;

        size_t index = (y * _width + x) * _pixelSize;

        static if (fmt == PixelFormat.L8)
        {
            _data[index] = cast(ubyte)c.r;
        }
        else if (fmt == PixelFormat.LA8)
        {
            _data[index] = cast(ubyte)c.r;
            _data[index+1] = cast(ubyte)c.a;
        }
        else if (fmt == PixelFormat.RGB8)
        {
            _data[index] = cast(ubyte)c.r;
            _data[index+1] = cast(ubyte)c.g;
            _data[index+2] = cast(ubyte)c.b;
        }
        else if (fmt == PixelFormat.RGBA8)
        {
            _data[index] = cast(ubyte)c.r;
            _data[index+1] = cast(ubyte)c.g;
            _data[index+2] = cast(ubyte)c.b;
            _data[index+3] = cast(ubyte)c.a;
        }
        else if (fmt == PixelFormat.L16)
        {
            _data[index] = cast(ubyte)(c.r >> 8);
            _data[index+1] = cast(ubyte)(c.r & 0xFF);
        }
        else if (fmt == PixelFormat.LA16)
        {
            _data[index] = cast(ubyte)(c.r >> 8);
            _data[index+1] = cast(ubyte)(c.r & 0xFF);
            _data[index+2] = cast(ubyte)(c.a >> 8);
            _data[index+3] = cast(ubyte)(c.a & 0xFF);
        }
        else if (fmt == PixelFormat.RGB16)
        {
            _data[index] = cast(ubyte)(c.r >> 8);
            _data[index+1] = cast(ubyte)(c.r & 0xFF);
            _data[index+2] = cast(ubyte)(c.g >> 8);
            _data[index+3] = cast(ubyte)(c.g & 0xFF);
            _data[index+4] = cast(ubyte)(c.b >> 8);
            _data[index+5] = cast(ubyte)(c.b & 0xFF);
        }
        else if (fmt == PixelFormat.RGBA16)
        {
            _data[index] = cast(ubyte)(c.r >> 8);
            _data[index+1] = cast(ubyte)(c.r & 0xFF);
            _data[index+2] = cast(ubyte)(c.g >> 8);
            _data[index+3] = cast(ubyte)(c.g & 0xFF);
            _data[index+4] = cast(ubyte)(c.b >> 8);
            _data[index+5] = cast(ubyte)(c.b & 0xFF);
            _data[index+6] = cast(ubyte)(c.a >> 8);
            _data[index+7] = cast(ubyte)(c.a & 0xFF);
        }
        else
        {
            assert (0, "Image.opIndexAssign is not implemented for PixelFormat." ~ to!string(fmt));
        }

        return c;
    }

    protected:

    uint _width;
    uint _height;
    uint _bitDepth;
    uint _channels;
    uint _pixelSize;
    ubyte[] _data;
}

alias Image!(PixelFormat.L8) ImageL8;
alias Image!(PixelFormat.LA8) ImageLA8;
alias Image!(PixelFormat.RGB8) ImageRGB8;
alias Image!(PixelFormat.RGBA8) ImageRGBA8;

alias Image!(PixelFormat.L8) ImageL16;
alias Image!(PixelFormat.LA8) ImageLA16;
alias Image!(PixelFormat.RGB8) ImageRGB16;
alias Image!(PixelFormat.RGBA8) ImageRGBA16;
