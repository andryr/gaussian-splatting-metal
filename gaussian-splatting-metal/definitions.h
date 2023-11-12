//
//  definitions.h
//  gaussian-splatting-metal
//
//  Created by Andry Rafaralahy on 11/10/2023.
//

#ifndef definitions_h
#define definitions_h

#include <simd/simd.h>


struct Vertex {
    vector_float3 position;
};

struct TexCoord {
    vector_float2 coord;
};

struct Gaussian {
    float x;
    float y;
    float z;
    float nx;
    float ny;
    float nz;
    float f_dc_0;
    float f_dc_1;
    float f_dc_2;
    float f_rest_0;
    float f_rest_1;
    float f_rest_2;
    float f_rest_3;
    float f_rest_4;
    float f_rest_5;
    float f_rest_6;
    float f_rest_7;
    float f_rest_8;
    float f_rest_9;
    float f_rest_10;
    float f_rest_11;
    float f_rest_12;
    float f_rest_13;
    float f_rest_14;
    float f_rest_15;
    float f_rest_16;
    float f_rest_17;
    float f_rest_18;
    float f_rest_19;
    float f_rest_20;
    float f_rest_21;
    float f_rest_22;
    float f_rest_23;
    float f_rest_24;
    float f_rest_25;
    float f_rest_26;
    float f_rest_27;
    float f_rest_28;
    float f_rest_29;
    float f_rest_30;
    float f_rest_31;
    float f_rest_32;
    float f_rest_33;
    float f_rest_34;
    float f_rest_35;
    float f_rest_36;
    float f_rest_37;
    float f_rest_38;
    float f_rest_39;
    float f_rest_40;
    float f_rest_41;
    float f_rest_42;
    float f_rest_43;
    float f_rest_44;
    float opacity;
    float scale_0;
    float scale_1;
    float scale_2;
    float rot_0;
    float rot_1;
    float rot_2;
    float rot_3;
};

struct zItem {
    uint32_t index;
    int32_t z;
};

#endif /* definitions_h */
