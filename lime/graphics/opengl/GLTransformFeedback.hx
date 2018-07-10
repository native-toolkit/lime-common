package lime.graphics.opengl; #if (!lime_doc_gen || lime_opengl || lime_opengles || lime_webgl)
#if ((lime_opengl || lime_opengles) && !display)


import lime.graphics.opengl.GL;

@:forward(id)


abstract GLTransformFeedback(GLObject) from GLObject to GLObject {
	
	
	@:from private static function fromInt (id:Int):GLTransformFeedback {
		
		return GLObject.fromInt (TRANSFORM_FEEDBACK, id);
		
	}
	
	
}


#elseif (lime_webgl && !display)
@:native("WebGLTransformFeedback")
extern class GLTransformFeedback {}
#else
typedef GLTransformFeedback = Dynamic;
#end
#end