float4x4 mWIT : WorldInverseTranspose;
float4x4 mWVP : WorldViewProjection;
float4x4 mW : World;
float4x4 mVI: ViewInverse;


float3 xLightPos  = {-25.0f,100.0f,75.0f};
float3 xLightColor = {1.0f,1.0f,1.0f};

// Ambient Light
float3 xAmbientColor = {0.07f,0.07f,0.07f};

float xKs  = 0.4;  // specular intensity

float xEccentricity = 0.3; //Highlight Eccentricity


float xBump  = 1.0; // Bump intensity

float xKr  = 0.5; // Reflection intensity

bool xPomOn;

texture2D xDiffuseTexture; 


SamplerState PlanarSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Wrap;
    AddressV = Wrap;
       
};

texture2D xBumpTexture;

//Zaczytanie tekstury cementu i mapy wysokosci 
texture2D xConcreteTexture;
texture2D xHeightMap;
texture2D xTga;
float4 xDimension;

//POM variables
float xAlpha;
float4 xCameraPos;
float4 xTexDimension;

texture2D xReflectionTexture;

SamplerState CubeSampler 
{    
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
    AddressW = Clamp;
};


struct VS_IN {
    float3 Position	: POSITION;
    float4 UV		: TEXCOORD0;
    float4 Normal	: NORMAL;
    float4 Tangent	: TANGENT;
    float4 Binormal	: BINORMAL;
};


struct PS_IN {
    float4 HPosition	: SV_POSITION;
    float2 UV		: TEXCOORD0;
    float3 LightVec	: TEXCOORD1;
    float3 WorldNormal	: TEXCOORD2;
    float3 WorldTangent	: TEXCOORD3;
    float3 WorldBinormal : TEXCOORD4;
    float3 WorldView	: TEXCOORD5;
	float3 ViewW        : TEXCOORD6;
//	float3 LightTS      : TEXCOORD7;
//	float3 VTS          : TEXCOORD7;
};
 


PS_IN VS(VS_IN IN) {
    PS_IN OUT = (PS_IN)0;
    OUT.WorldNormal = mul(IN.Normal,mWIT).xyz;
    OUT.WorldTangent = mul(IN.Tangent,mWIT).xyz;
    OUT.WorldBinormal = mul(IN.Binormal,mWIT).xyz;
    float4 Po = float4(IN.Position.xyz,1);
    float3 Pw = mul(Po,mW).xyz;
    OUT.LightVec = (xLightPos - Pw);

	OUT.ViewW = mul(xCameraPos - mul(IN.Position.xyz, mW), mWIT).xyz;
    OUT.UV = float2(1- IN.UV.x, 1- IN.UV.y);
    OUT.WorldView = normalize(mVI[3].xyz - Pw);
    OUT.HPosition = mul(Po,mWVP);
    return OUT;
}


void blinn_shading(PS_IN IN,
		    float3 LightColor,
		    float3 Nn,
		    float3 Ln,
		    float3 Vn,
		    out float3 DiffuseContrib,
		    out float3 SpecularContrib)
{
    float3 Hn = normalize(Vn + Ln);
    float hdn = dot(Hn,Nn);
    float3 R = reflect(-Ln,Nn);
    float rdv = dot(R,Vn);
    rdv = max(rdv,0.001);
    float ldn=dot(Ln,Nn);
    ldn = max(ldn,0.0);
    float ndv = dot(Nn,Vn);
    float hdv = dot(Hn,Vn);
    float eSq = xEccentricity*xEccentricity;
    float distrib = eSq / (rdv * rdv * (eSq - 1.0) + 1.0);
    distrib = distrib * distrib;
    float Gb = 2.0 * hdn * ndv / hdv;
    float Gc = 2.0 * hdn * ldn / hdv;
    float Ga = min(1.0,min(Gb,Gc));
    float fresnelHack = 1.0 - pow(ndv,5.0);
    hdn = distrib * Ga * fresnelHack / ndv;
    DiffuseContrib = ldn * LightColor;
    SpecularContrib = hdn * xKs * LightColor;
}

float4 PS(PS_IN IN) :SV_TARGET {
    float3 diffContrib;
    float3 specContrib;
    float3 Ln = normalize(IN.LightVec);
    float3 Vn = normalize(IN.WorldView);
    float3 Nn = normalize(IN.WorldNormal);
    float3 Tn = normalize(IN.WorldTangent);
    float3 Bn = normalize(IN.WorldBinormal);
    float3 bump = xBump * (xBumpTexture.Sample(PlanarSampler,IN.UV).rgb - float3(0.5,0.5,0.5));
    Nn = Nn + bump.x*Tn + bump.y*Bn;
    Nn = normalize(Nn);
	blinn_shading(IN,xLightColor,Nn,Ln,Vn,diffContrib,specContrib);
    float3 diffuseColor = xConcreteTexture.Sample(PlanarSampler, IN.UV).rgb;
    float3 result = specContrib+(diffuseColor*(diffContrib+xAmbientColor));
    float3 R = -reflect(Vn,Nn);
    float3 reflColor = xKr * xReflectionTexture.Sample(CubeSampler,R.xyz).rgb;
    result += diffuseColor*reflColor;
    return float4(result,1);
}

float4 PSHeight(PS_IN IN) :SV_TARGET {
    float3 diffContrib;
    float3 specContrib;
    float3 Ln = normalize(IN.LightVec);
    float3 Vn = normalize(IN.WorldView);
    float3 Nn = normalize(IN.WorldNormal);
    float3 Tn = normalize(IN.WorldTangent);
    float3 Bn = normalize(IN.WorldBinormal);

	//Moje
	//krok po teksturze wysokosci
	float2 dx = float2(1.0 / xDimension.x,0.0f);
	float2 dy = float2(0.0f, 1.0 / xDimension.y);

	float3 theta = float3(1.0, 0.0, xHeightMap.Sample(PlanarSampler, IN.UV + dx).x - xHeightMap.Sample(PlanarSampler, IN.UV - dx).x); 
	float3 beta = float3(0.0, 1.0, xHeightMap.Sample(PlanarSampler, IN.UV + dy).x - xHeightMap.Sample(PlanarSampler, IN.UV - dy).x);
	float3 hbump = normalize(cross(beta,theta));

	float3 above = float3(1.0, 0.0, xHeightMap.Sample(PlanarSampler, IN.UV + dx).x - xHeightMap.Sample(PlanarSampler, IN.UV).x);
	float3 next = float3(0.0, 1.0, xHeightMap.Sample(PlanarSampler, IN.UV + dy).x - xHeightMap.Sample(PlanarSampler, IN.UV).x);
	float3 hhbump = normalize(cross(next,above));
	//koniec mojego

    float3 bump = xBump * (xBumpTexture.Sample(PlanarSampler,IN.UV).rgb - float3(0.5,0.5,0.5));

	bump = xBump * hhbump;

    Nn = Nn + bump.x*Tn + bump.y*Bn;
    Nn = normalize(Nn);


	blinn_shading(IN,xLightColor,Nn,Ln,Vn,diffContrib,specContrib);
    float3 diffuseColor = xConcreteTexture.Sample(PlanarSampler, IN.UV).rgb;
    float3 result = specContrib+(diffuseColor*(diffContrib+xAmbientColor));
    float3 R = -reflect(Vn,Nn);
    float3 reflColor = xKr * xReflectionTexture.Sample(CubeSampler,R.xyz).rgb;
    result += diffuseColor*reflColor;
    return float4(result,1);
}

float4 PSPOM(PS_IN IN) :SV_TARGET {
    float3 diffContrib;
    float3 specContrib;
    float3 Ln = normalize(IN.LightVec);
    float3 Vn = normalize(IN.WorldView);
    float3 Nn = normalize(IN.WorldNormal);
    float3 Tn = normalize(IN.WorldTangent);
    float3 Bn = normalize(IN.WorldBinormal);
	//minimalny krok po x/y w teksturze
	float2 dtx = float2(1.0f / xTexDimension.x,0.0f);
	float2 dty = float2(0.0f, 1.0f / xTexDimension.y);
	float i = 0.0f;
	float stepCount = 0;
	float resultOffset = 0;
	bool found = false;
	float3 PixTangent = float3(0.0f,0.0f,0.0f);
	float RayHeight = 0.0f;
	float TexHeight = 0.0f;
	float smallerStep = min(dtx.x, dty.y);
	//do interpolacji
	float prevDif = 0;
	float curDif = 0;
	float stepBasedOnAngle = max(0.2f,dot(Nn, Vn));


	//Moje
	float3 Eye = normalize((xCameraPos.xyz - IN.HPosition.xyz));
	float3x3 TBN = float3x3( Tn, Bn, Nn);
	float3 EyeTangent = (mul(  TBN, Vn));		//float3 EyeTangent = mul(TBN, Vn)
	float3 EyeRayTangent = normalize(EyeTangent);
	float EyeRTRatio = abs(EyeRayTangent.x / EyeRayTangent.z);
	//lub innymi slowy - x^2 + y^2 / z. Poprzednia metoda robila zaleznosc Z od X i przy x->0 lub z->0 wychodzily kretynskie
	//proporcje. w zwiazku z tym lepiej jest uzaleznic od przeciwprostokatnej zlozonej z X i Y i jestesmy w domu
	//Podejscie poczatkowe, czyli abs(x/z) jest dobre przy katach wiekszych od 5 stopni
	//EyeRTRatio = sqrt(EyeRayTangent.x * EyeRayTangent.x + EyeRayTangent.y * EyeRayTangent.y) / EyeRayTangent.z;
	EyeRTRatio = sqrt(length(EyeRayTangent) * length(EyeRayTangent) - EyeRayTangent.z * EyeRayTangent.z) / EyeRayTangent.z;

	//o co w tym chodzi?;O
	int maxStepNumber = 100;
	int minStepNumber = 8;
	int nNumSteps = (int) lerp( maxStepNumber, minStepNumber, dot( Nn, Vn ) );

	PixTangent = mul(TBN, IN.HPosition);
	//czy to robi sens?
	float2 ParallaxStep = normalize(float2( 1 * EyeTangent.x, -1 * EyeTangent.y));
	float2 ParallaxOffset = IN.UV;
	float2 resultParallaxOffset = IN.UV;
	//float ParallaxZVal = abs(normalize(EyeTangent).z);
	//float2 ParallaxStep = -1 * normalize(Eye.xy);		//-1 bo przemieszczamy sie w przeciwnym kierunku niz wektor oka
	ParallaxStep.x = ParallaxStep.x * smallerStep;//  * stepBasedOnAngle;
	ParallaxStep.y = ParallaxStep.y * smallerStep;//  * stepBasedOnAngle;

	//tatarchuk
	/*
    float fLength         = length( EyeTangent );
	float fParallaxLength = sqrt( fLength * fLength - EyeTangent.z * EyeTangent.z ) / EyeTangent.z; 
	*/
	//return float4((float)1/nNumSteps, (float)1/nNumSteps, (float)1/nNumSteps, 1);
	/*
	if(EyeRTRatio < 0.001f)
		return float4(1.0f,0.0f,0.0f,1);
	if(EyeRTRatio > 1.0f)
		return float4(0.0f,1.0f,0.0f,1);
	return float4((float)EyeRTRatio/1, (float)EyeRTRatio/1, (float)EyeRTRatio/1, 1);
	*/

	//EyeRTRatio = max(EyeRTRatio, 0.1f);
	RayHeight = xAlpha;
	for(uint i=0 ; i < 512  ;i++)
	{
		TexHeight = xAlpha * ( xTga.Sample(PlanarSampler, IN.UV + stepCount*ParallaxStep).a);
		RayHeight -= (float)1 / EyeRTRatio ;
		//RayHeight -= (float) 1 / nNumSteps ;
		curDif = abs(RayHeight - TexHeight);

		if(!found)
		{
			if(RayHeight <= TexHeight)
			{
				resultOffset = stepCount + prevDif/(curDif + prevDif);		//2gi skladnik sumy to interpolacja
				resultParallaxOffset = ParallaxOffset + prevDif/(curDif + prevDif) * ParallaxStep;
				//resultOffset = stepCount;
				//resultParallaxOffset = ParallaxOffset;
				found = true;
			}
		}
		stepCount ++;
		ParallaxOffset += ParallaxStep;
		prevDif = curDif;		//przepisz obecna roznice wysokosci na poprzednia

	}
	if(found == false)
		resultParallaxOffset = ParallaxOffset;

	//czy POM ma byc wlaczony
	resultParallaxOffset = xPomOn == true ? resultParallaxOffset : IN.UV;
		
	//proba oswietlenia
	//1) Z mapy wysokosci
	/*
	float3 NTS = normalize(mul( TBN, Nn ));
	float3 theta = float3(1.0, 0.0, xHeightMap.Sample(PlanarSampler, resultParallaxOffset + dtx).x - xHeightMap.Sample(PlanarSampler, resultParallaxOffset - dtx).x);
	float3 beta = float3(0.0, 1.0, xHeightMap.Sample(PlanarSampler, resultParallaxOffset + dty).x - xHeightMap.Sample(PlanarSampler, resultParallaxOffset - dty).x);
	float3 bump = normalize(cross(theta,beta));
    NTS = NTS + bump.x*Tn + bump.y*Bn;
	NTS = NTS + mul(TBN, bump);
	NTS = normalize(NTS);
	*/
	//2) Z .tga
	float3 NTS = float3(xTga.Sample(PlanarSampler, resultParallaxOffset).rgb);
	NTS = normalize(mul(TBN, NTS));

	float3 LightTS = normalize(mul(TBN,Ln));
	float3 VTS = normalize(mul( TBN,Vn));
	blinn_shading(IN,xLightColor,NTS,LightTS,VTS,diffContrib,specContrib);
    float3 diffuseColor = xConcreteTexture.Sample(PlanarSampler, resultParallaxOffset).rgb;
    float3 resultBlin = specContrib+(diffuseColor*(diffContrib+xAmbientColor));

	float a = xTga.Sample(PlanarSampler, resultParallaxOffset).a;
//	return float4(a,a,a,1);
    return float4(resultBlin,1);
	
	float3 result = xConcreteTexture.Sample(PlanarSampler, resultParallaxOffset).rgb;
    return float4(result,1);
}


RasterizerState DisableCulling
{
    CullMode = NONE;
};

DepthStencilState DepthEnabling
{
	DepthEnable = TRUE;
};

BlendState DisableBlend
{
	BlendEnable[0] = FALSE;
};

technique10 Blinn 	
{
    pass p0 {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PS() ) );
                
        SetRasterizerState(DisableCulling);       
		SetDepthStencilState(DepthEnabling, 0);
		SetBlendState(DisableBlend, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF);
    }
}

technique10 BlinnHeight
{
    pass p0 {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PSHeight() ) );
                
        SetRasterizerState(DisableCulling);       
		SetDepthStencilState(DepthEnabling, 0);
		SetBlendState(DisableBlend, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF);
    }
}

technique10 POM
{
    pass p0 {
        SetVertexShader( CompileShader( vs_4_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_4_0, PSPOM() ) );
                
        SetRasterizerState(DisableCulling);       
		SetDepthStencilState(DepthEnabling, 0);
		SetBlendState(DisableBlend, float4( 0.0f, 0.0f, 0.0f, 0.0f ), 0xFFFFFFFF);
    }
}

//bazgroly ale nie chce ich wyrzucac
/*
	//zmienne
	//wektor ktory prowadzimy od szukanego piksela i sprawdzamy jego znak
	float3 foundVec = float3(0.0f, 0.0f, 0.0f);
	float3 foundPix = float3(0.0f, 0.0f, 0.0f);
	float sumCurrent = 0.0f;
	float sumPrev = 0.0f;

	//to przed petla
	foundPix.xy = PixTangent.xy;
	foundPix.z = PixTangent.z;
	foundPix.z -= xAlpha * xTga.Sample(PlanarSampler, IN.UV).a;
	foundVec = normalize(PixTangent - foundPix);	
	sumCurrent = dot(foundVec, EyeTangent);
	sumPrev = 0.0f;
	float3 signOfVector = cross(foundVec, EyeTangent);		//1 lub -1
	


		sumPrev = sumCurrent;
		foundPix.xy = PixTangent.xy + stepSize*ParallaxDirection;
		//wpierw na wysokosc piksela gornego a pozniej odejmujemy
		foundPix.z = PixTangent.z;
		foundPix.z -= xAlpha * xHeightMap.Sample(PlanarSampler, IN.UV + stepSize*ParallaxDirection).x;

		foundVec = normalize(PixTangent - foundPix);
		sumCurrent = dot(foundVec, EyeTangent);
		*/

		/*
		if(!found)
		{
			if(sumCurrent < sumPrev)
			{
				resultOffset = stepSize;
				resultParallaxOffset = ParallaxOffset;
				found = true;
			}
		}
		*/

		/*
		if(!found)
		{
			if(dot(cross(foundVec, EyeTangent), signOfVector) < 0)
			{
				resultOffset = stepSize;
				resultParallaxOffset = ParallaxOffset;
				found = true;
			}
		}
*/