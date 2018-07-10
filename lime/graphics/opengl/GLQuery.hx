package lime.graphics.opengl; #if (!lime_doc_gen || lime_opengl || lime_opengles || lime_webgl)
#if ((lime_opengl || lime_opengles) && !display)


import lime.graphics.opengl.GL;

@:forward(id)


abstract GLQuery(GLObject) from GLObject to GLObject {
	
	
	@:from private static function fromInt (id:Int):GLQuery {
		
		return GLObject.fromInt (QUERY, id);
		
	}
	
	
}


#elseif (lime_webgl && !display)
@:native("WebGLQuery")
extern class GLQuery {}
#else
typedef GLQuery = Dynamic;
#end
#end