using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using SlimDX;
using SlimDX.Direct3D10;
using SlimDX.DXGI;
using DX10 = SlimDX.Direct3D10;
using DXGI = SlimDX.DXGI;
using SlimDX.D3DCompiler;


namespace SlimDXStart
{
    public class SDXCamera
    {
        public Vector3 Position;
        public Vector3 Up;
        public Vector3 Target;

        public SDXCamera()
        {
            Position = new Vector3(0, 0, -1);
            Up = new Vector3(0, 1, 0);
        }

        public void SetPositionSpherical(float phi, float theta, float radius)
        {
            float y = (float)(radius * Math.Sin(theta));
            float z = (float)(radius * Math.Cos(theta) * Math.Cos(phi));
            float x = (float)(radius * Math.Cos(theta) * Math.Sin(phi));
            if (Math.Cos(theta) > 0) Up = new Vector3(0, 1, 0);
            else Up = new Vector3(0, -1, 0);
            Position = new Vector3(x, y, z);
        }

        public Matrix CameraView
        {
            get
            {
                return Matrix.LookAtLH(Position, Target, Up);
            }
        }
    }
}
