#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// BUFFER_COLOR_SPACE Color space type for presentation; 0 = unknown, 1 = sRGB, 2 = scRGB, 3 = HDR10 ST2084, 4 = HDR10 HLG.

namespace myReshade {
#if BUFFER_COLOR_SPACE == 3 // PQ
	uniform bool ColorSpace <ui_label = "HDR PQ";> = true;
#else
	error_unknown_color_space
#endif

	uniform float PeakBrightness <
		ui_lable = "PeakBrightness";
		ui_type = "slider";
		ui_min = 500;
		ui_max = 1500;
		ui_step = 1;
	> = 1000;
	
	uniform float ContrastRange <
		ui_lable = "ContrastRange";
		ui_type = "slider";
		ui_min = 10;
		ui_max = 200;
		ui_step = 1;
	> = 50;
	
	uniform float Contrast <
		ui_lable = "Contrast";
		ui_type = "slider";
		ui_min = -1;
		ui_max = 1;
		ui_step = 0.01;
	> = 0;
		
	uniform float Saturation <
		ui_lable = "Saturation";
		ui_type = "slider";
		ui_min = -1;
		ui_max = 1;
		ui_step = 0.01;
	> = 0;
		
	float luminance(in float3 rgb) {
		//return dot(rgb, float3(0.2126, 0.7152, 0.0722));
		return dot(rgb, float3(0.2627, 0.6780, 0.0593));
	}

	float3 PS(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target {
		float3 rgb = tex2D(ReShade::BackBuffer, texcoord).xyz;
		// to linear
		const float m1 = 0.1593017578125;
		const float m2 = 78.84375;
		const float c1 = 0.8359375;
		const float c2 = 18.8515625;
		const float c3 = 18.6875;
		float3 e1m2 = pow(rgb, 1.0 / m2);
		rgb = pow(max(e1m2 - c1, 0.0) / (c2 - c3 * e1m2), 1.0 / m1);
		// scale and clip
		rgb = saturate(rgb * (10000.0 / PeakBrightness));

		if (Contrast != 0.0) {
			float lMax = ContrastRange / PeakBrightness;
			float3 l = clamp(rgb, 0.0, lMax) / lMax;
			float3 c = l < 0.5 ? (2.0 * l * l + l * l * (1.0 - 2.0 * l)) : (sqrt(l) * (2.0 * l - 1.0) + 2.0 * l * (1.0 - l));
			float3 lNew = saturate(lerp(l, c, Contrast));
			rgb = saturate(rgb * (lNew / l));
		}
		if (Saturation != 0.0) {
			rgb = saturate(lerp(luminance(rgb), rgb, 1.0 + Saturation));
		}
		// unscale
		rgb = saturate(rgb * (PeakBrightness / 10000.0));
		// to PQ
		float3 ym1 = pow(rgb, m1);
		rgb = pow((c1 + c2 * ym1) / (1.0 + c3 * ym1), m2);
		return rgb;
	}

	technique HDR {
		pass {
			VertexShader = PostProcessVS;
			PixelShader = PS;
		}
	}
}
