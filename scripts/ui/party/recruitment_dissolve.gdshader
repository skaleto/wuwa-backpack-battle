shader_type canvas_item;
render_mode unshaded;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float chosen : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 vec4 ink=texture(TEXTURE,UV)*COLOR;
 float d=min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y));
 float field=d*1.55+noise(UV*vec2(25,40))*.23+.015;
 float cut=dissolve*1.02;
 float mask=1.0-smoothstep(field-.012,field+.012,cut);
 float edge=(1.0-smoothstep(.012,.068,field-cut))*step(cut,field)*step(.001,dissolve);
 ink.rgb=mix(ink.rgb,vec3(1.0,.94,.73),edge*.88);
 // The selected edge has a warm, restrained rim; it never changes hit geometry.
 float rim=step(.001,ink.a)*(1.0-smoothstep(.014,.031,d));
 ink.rgb=mix(ink.rgb,vec3(1.0,.82,.43),rim*chosen*.32);
 ink.a*=mask;
 COLOR=ink;
}
