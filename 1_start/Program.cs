using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using SlimDX;
using SlimDX.Direct3D10;
using SlimDX.DXGI;
using DX10=SlimDX.Direct3D10;
using DXGI=SlimDX.DXGI;
using SlimDX.Windows;
using SlimDX.D3DCompiler;
using ColladaReader;
using SlimDX.DirectInput;

namespace SlimDXStart
{
    class Program
    {
        #region Device, swapchain and other variables
        static public RenderForm MainWindow;
        static public DX10.Device device;
        static public DXGI.SwapChain swapchain;
        static public Texture2D backbuffer, depthbuffer;
        static public RenderTargetView renderview;
        static public DepthStencilState depthstate;
        static public DepthStencilView depthview;

        static public float time;

        static public float phi, theta, radius;
        #endregion 

        #region Geometry and Virtual Assets
        static public CGeometry M;
        static public CGeometry L;
        static public SDXCamera Camera;
        static public Matrix Projection;
        static public float deltar = 5;
        static public float deltaang = 0.02f;
        #endregion

        #region Effect
        static public DX10.Effect effect;
        
        #endregion 

        #region Textures
        static public Texture2D Diffuse;
        static public Texture2D BumpMap;
        static public Texture2D Reflection;

        //moje
        static public Texture2D Concrete;
        static public Texture2D HeightMap;
        static public Texture2D TgaTex;
        static public Vector4 HeightDimension;
        static public Vector4 TexDimension;
        static public bool POMOn;
        #endregion

        #region mysz
        //mysz , nie dziala
        static public SlimDX.RawInput.Device mouse;
        static public SlimDX.RawInput.MouseInfo originalMouseInfo;
        #endregion

        #region zmienne do Parallax Occlusion Mapping
        static public float alpha; //wspolczynnik skali
        static public Vector3 CameraPos;
        #endregion

        #region Lights
        public static Vector3 LightPosition;
        #endregion

        #region Informacje dot. framow
        //moje
        static public float fps;
        static public int frames = 0, PrevTickCount = 1, EndTickCount = 1;
        static public int FramePrevTickCount = 1;

        static public void UpdateFramerate()
        {
            frames++;
            if (Math.Abs(Environment.TickCount - FramePrevTickCount) > 1000)
            {
                fps = (float)frames * 1000 / Math.Abs(Environment.TickCount - FramePrevTickCount);
                FramePrevTickCount = Environment.TickCount;
                frames = 0;
            }

        }
        #endregion


        static public void InitializeMainWindow()
        {
            MainWindow = new RenderForm("First SlimDX example");
            MainWindow.KeyDown+=new System.Windows.Forms.KeyEventHandler(MainWindow_KeyDown);
            POMOn = true;
        }

        static public void MainWindow_KeyDown(object sender, KeyEventArgs e)
        {
            switch (e.KeyCode)
            {
                case Keys.A: radius += deltar; break;
                case Keys.Z: radius -= deltar; break;
                case Keys.Left: phi -= deltaang; break;
                case Keys.Right: phi += deltaang; break;
                case Keys.Up: theta -= deltaang; break;
                case Keys.Down: theta += deltaang; break;

                //od swiatla
                case Keys.U: LightPosition.X += 1.1f; break;
                case Keys.J: LightPosition.X -= 1.1f; break;
                case Keys.I: LightPosition.Y += 1.1f; break;
                case Keys.K: LightPosition.Y -= 1.1f; break;
                case Keys.O: LightPosition.Z += 1.1f; break;
                case Keys.L: LightPosition.Z -= 1.1f; break;

                //od POM
                case Keys.Q: POMOn = true; effect.GetVariableByName("xPomOn").AsScalar().Set(POMOn); break;
                case Keys.W: POMOn = false; effect.GetVariableByName("xPomOn").AsScalar().Set(POMOn); break;

                                        //nie wiecej niz 100
                case Keys.R: alpha += 1; alpha = Math.Min(alpha, 100.0f); effect.GetVariableByName("xAlpha").AsScalar().Set(alpha); break;
                                        //nie mniej niz 1
                case Keys.T: alpha -= 1; alpha = Math.Max(alpha, 1.0f); effect.GetVariableByName("xAlpha").AsScalar().Set(alpha); break;
            }
            Camera.SetPositionSpherical(phi, theta, radius);
            Matrix V = Camera.CameraView;
            Matrix VI = Matrix.Invert(V);

            CameraPos.X = Camera.Position.X;
            CameraPos.Y = Camera.Position.Y;
            CameraPos.Z = Camera.Position.Z;
            effect.GetVariableByName("xCameraPos").AsVector().Set(CameraPos);
            effect.GetVariableByName("mWVP").AsMatrix().SetMatrix(V * Projection);
            effect.GetVariableByName("mVI").AsMatrix().SetMatrix(VI); 
        }

        static public void InitializeDevice()
        {
            SwapChainDescription D = new SwapChainDescription()
            {
                BufferCount = 1,
                Usage = Usage.RenderTargetOutput,
                OutputHandle = MainWindow.Handle,
                IsWindowed = true,
                Flags = SwapChainFlags.AllowModeSwitch,
                SwapEffect = SwapEffect.Discard,
                SampleDescription = new SampleDescription(1, 0),
                ModeDescription = new ModeDescription(0, 0, new Rational(60, 1), Format.R8G8B8A8_UNorm)                                
            };

            DX10.Device.CreateWithSwapChain(null, DriverType.Hardware, DeviceCreationFlags.None, D, out device, out swapchain);

            device.Factory.SetWindowAssociation(MainWindow.Handle, WindowAssociationFlags.IgnoreAll);
            
        }

        static public void InitializeOutputMerger()
        {
            backbuffer = Texture2D.FromSwapChain<Texture2D>(swapchain, 0);            
            renderview = new RenderTargetView(device, backbuffer);
           
            device.Rasterizer.SetViewports(new Viewport(0, 0, MainWindow.ClientSize.Width, MainWindow.ClientSize.Height, 0.0f, 1.0f));
            
            DX10.Texture2DDescription dtd = new Texture2DDescription();
            dtd.Width = MainWindow.ClientSize.Width;
            dtd.Height = MainWindow.ClientSize.Height;
            dtd.MipLevels = 1;
            dtd.ArraySize = 1;
            dtd.BindFlags = BindFlags.DepthStencil;
            dtd.CpuAccessFlags = CpuAccessFlags.None;
            dtd.Format = Format.D32_Float;
            dtd.SampleDescription = new SampleDescription(1, 0);
            dtd.Usage = ResourceUsage.Default;
            dtd.OptionFlags = ResourceOptionFlags.None;

            depthbuffer = new Texture2D(device, dtd);


            depthview = new DepthStencilView(device, depthbuffer);

            DX10.DepthStencilStateDescription stencilStateDesc = new SlimDX.Direct3D10.DepthStencilStateDescription();
            stencilStateDesc.IsDepthEnabled = true;
            stencilStateDesc.IsStencilEnabled = false;
            stencilStateDesc.DepthWriteMask = DX10.DepthWriteMask.All;
            stencilStateDesc.DepthComparison = DX10.Comparison.Less;            

            device.OutputMerger.SetTargets(depthview , renderview);
            depthstate = DepthStencilState.FromDescription(device, stencilStateDesc);

            //inicjalizacja kamery
            CameraPos = new Vector3(0, 0, 0);

        }

        static public void InitializeTextures()
        {
            Diffuse = Texture2D.FromFile(device, "gold.jpg");
            BumpMap = Texture2D.FromFile(device, "normal.jpg");           
            Reflection = Texture2D.FromFile(device, "cube.dds");
            TgaTex = Texture2D.FromFile(device, "rocksdds.dds");
            //TgaTex = Texture2D.FromFile(device, "fourDDS.dds");

            HeightMap = Texture2D.FromFile(device, "mapa_wysokosci2.jpg");
            Image heightMap = Bitmap.FromFile("mapa_wysokosci2.jpg");
            HeightDimension.X = heightMap.Width;
            HeightDimension.Y = heightMap.Height;
            HeightDimension.Z = 1.0f;
            HeightDimension.W = 1.0f;

            //Concrete = Texture2D.FromFile(device, "concrete.bmp");
            Concrete = Texture2D.FromFile(device, "rocks.jpg");
            Image texImg = Bitmap.FromFile("rocks.jpg");
            TexDimension.X = texImg.Width;
            TexDimension.Y = texImg.Height;
            TexDimension.Z = 1.0f;
            TexDimension.W = 1.0f;

            /*
            TgaTex = Texture2D.FromFile(device, "wall3_height.jpg");
            Concrete = Texture2D.FromFile(device, "wall3_base.jpg");
            Image texImg = Bitmap.FromFile("wall3_base.jpg");
             */
        }
        
        static public void InitializeGeometry()
        {

            /*
            CDocument doc = new CDocument(device, "box.dae");
            M = doc.Geometries["Box001"];
             */
            
            CDocument doc = new CDocument(device, "plane.dae");
            M = doc.Geometries["Plane001"];
            

            CDocument docL = new CDocument(device, "ball.dae");
            L = docL.Geometries["GeoSphere001"];

            Camera = new SDXCamera();
            phi = 0; theta = 0; radius = M.BSphere.Radius * 3;
            Camera.SetPositionSpherical(phi, theta, radius);
            Camera.Target = M.BSphere.Center;
            Camera.Up = new Vector3(0, 1, 0);

            Projection = Matrix.PerspectiveFovLH((float)Math.PI/4, (float)MainWindow.ClientSize.Width/(float)MainWindow.ClientSize.Height, 0.01f, M.BSphere.Radius * 10);

            //LightPosition = new Vector3(M.BSphere.Radius * 2, 0, 0);
            LightPosition = new Vector3(M.BSphere.Radius * 2, 0, M.BSphere.Radius * 2);
        }

        static public void InitializeEffect()
        {
            effect = DX10.Effect.FromFile(device, "blinn.fx", "fx_4_0");
            Matrix V = Camera.CameraView;
            Matrix VI = Matrix.Invert(V);
            effect.GetVariableByName("mWVP").AsMatrix().SetMatrix(V * Projection);
            effect.GetVariableByName("mVI").AsMatrix().SetMatrix(VI); 
            effect.GetVariableByName("mW").AsMatrix().SetMatrix(Matrix.Identity);
            effect.GetVariableByName("mWIT").AsMatrix().SetMatrix(Matrix.Identity);
            effect.GetVariableByName("xDiffuseTexture").AsResource().SetResource(new ShaderResourceView(device, Diffuse));
            effect.GetVariableByName("xBumpTexture").AsResource().SetResource(new ShaderResourceView(device, BumpMap));
            effect.GetVariableByName("xReflectionTexture").AsResource().SetResource(new ShaderResourceView(device, Reflection));

            //zaczytanie ekstra tekstury i mapy wysokosci ; pobranie wymiarow
            effect.GetVariableByName("xTga").AsResource().SetResource(new ShaderResourceView(device, TgaTex));
            effect.GetVariableByName("xConcreteTexture").AsResource().SetResource(new ShaderResourceView(device, Concrete));
            effect.GetVariableByName("xHeightMap").AsResource().SetResource(new ShaderResourceView(device, HeightMap));
            effect.GetVariableByName("xDimension").AsVector().Set(HeightDimension);
            //dane do POM ; alfa - wspolczynnik wysokosci ; kamera
            alpha = 35.0f;
            effect.GetVariableByName("xAlpha").AsScalar().Set(alpha);
            CameraPos.X = Camera.Position.X;
            CameraPos.Y = Camera.Position.Y;
            CameraPos.Z = Camera.Position.Z;
            effect.GetVariableByName("xCameraPos").AsVector().Set(CameraPos);
            effect.GetVariableByName("xTexDimension").AsVector().Set(TexDimension);
            effect.GetVariableByName("xPomOn").AsScalar().Set(POMOn);
        }

        
        static public void UpdateLight()
        {
            //LightPosition = new Vector3((float)(M.BSphere.Radius *2.0f *Math.Cos(time)), (float)(M.BSphere.Radius*2.0f*Math.Sin(time)), (float)(M.BSphere.Radius*2.0f*Math.Sin(time/10)));
            effect.GetVariableByName("xLightPos").AsVector().Set(LightPosition);
        }

        static public void RenderFrame()
        {
            UpdateFramerate();
            PrevTickCount = Environment.TickCount;
            device.ClearDepthStencilView(depthview, DepthStencilClearFlags.Depth, 1, 0);
            device.ClearRenderTargetView(renderview, Color.LightBlue);
            device.OutputMerger.DepthStencilState = depthstate;
            UpdateLight();
            time += 0.01f;
                                
            //EffectTechnique t = effect.GetTechniqueByName("Blinn");
            //EffectTechnique t = effect.GetTechniqueByName("BlinnHeight");
            EffectTechnique t = effect.GetTechniqueByName("POM");

            M.Render(t);
            //L.Render(t);


            swapchain.Present(0, PresentFlags.None);
            //poczekaj
            EndTickCount = Environment.TickCount;
            while (Math.Abs(Environment.TickCount - PrevTickCount) < 16) ;
            Console.WriteLine("FPS {0:0.0} ; Light Pos: {1:0} {2:0} {3:0}", fps, LightPosition, LightPosition.Y, LightPosition.Z);
            Console.WriteLine("Rad {0:0.00}, Phi {1:0.00}, Theta {2:0.00}", radius, phi, theta);
           
        }


        static public void DisposeAll()
        {
            
            effect.Dispose();
            renderview.Dispose();
            backbuffer.Dispose();
            device.Dispose();
            swapchain.Dispose();
        }

        static void Main()
        {
            InitializeMainWindow();
            InitializeDevice();
            InitializeOutputMerger();
            InitializeGeometry();
            InitializeTextures();
            InitializeEffect();
            
            MessagePump.Run(MainWindow, RenderFrame);

            DisposeAll();
        }
    }
}
