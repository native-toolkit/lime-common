package lime._internal.backend.native;


import haxe.io.Bytes;
import lime._internal.backend.native.NativeCFFI;
import lime.app.Application;
import lime.graphics.cairo.Cairo;
import lime.graphics.cairo.CairoFormat;
import lime.graphics.cairo.CairoImageSurface;
import lime.graphics.cairo.CairoSurface;
import lime.graphics.opengl.GL;
import lime.graphics.CairoRenderContext;
import lime.graphics.Image;
import lime.graphics.ImageBuffer;
import lime.graphics.OpenGLRenderContext;
import lime.graphics.RenderContext;
import lime.math.Rectangle;
import lime.math.Vector2;
import lime.system.Display;
import lime.system.DisplayMode;
import lime.system.JNI;
import lime.system.System;
import lime.ui.Window;
import lime.utils.UInt8Array;


#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end

@:access(lime._internal.backend.native.NativeCFFI)
@:access(lime._internal.backend.native.NativeOpenGLRenderContext)
@:access(lime.app.Application)
@:access(lime.graphics.cairo.Cairo)
@:access(lime.graphics.opengl.GL)
@:access(lime.graphics.OpenGLRenderContext)
@:access(lime.graphics.RenderContext)
@:access(lime.system.DisplayMode)
@:access(lime.ui.Window)


class NativeWindow {
	
	
	public var handle:Dynamic;
	
	private var closing:Bool;
	private var displayMode:DisplayMode;
	private var frameRate:Float;
	private var parent:Window;
	private var useHardware:Bool;
	
	#if lime_cairo
	private var cacheLock:Dynamic;
	private var cairo:Cairo;
	private var primarySurface:CairoSurface;
	#end
	
	
	public function new (parent:Window) {
		
		this.parent = parent;
		frameRate = 60;
		
		displayMode = new DisplayMode (0, 0, 0, 0);
		
	}
	
	
	public function alert (message:String, title:String):Void {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_alert (handle, message, title);
			#end
			
		}
		
	}
	
	
	public function close ():Void {
		
		if (!closing) {
			
			closing = true;
			parent.onClose.dispatch ();
			
			if (!parent.onClose.canceled) {
				
				if (handle != null) {
					
					#if (!macro && lime_cffi)
					NativeCFFI.lime_window_close (handle);
					#end
					handle = null;
					
				}
				
			} else {
				
				closing = false;
				
			}
			
		}
		
		
		
	}
	
	
	public function create (application:Application):Void {
		
		var title = (parent.__title != null && parent.__title != "") ? parent.__title : "Lime Application";
		var flags = 0;
		
		if (parent.config != null) {
			
			if (Reflect.hasField (parent.config, "antialiasing")) {
				
				if (parent.config.antialiasing >= 4) {
					
					flags |= cast WindowFlags.WINDOW_FLAG_HW_AA_HIRES;
					
				} else if (parent.config.antialiasing >= 2) {
					
					flags |= cast WindowFlags.WINDOW_FLAG_HW_AA;
					
				}
				
			}
			
			if (Reflect.hasField (parent.config, "allowHighDPI") && parent.config.allowHighDPI) flags |= cast WindowFlags.WINDOW_FLAG_ALLOW_HIGHDPI;
			if (Reflect.hasField (parent.config, "alwaysOnTop") && parent.config.alwaysOnTop) flags |= cast WindowFlags.WINDOW_FLAG_ALWAYS_ON_TOP;
			//if (Reflect.hasField (parent.config, "borderless") && parent.config.borderless) flags |= cast WindowFlags.WINDOW_FLAG_BORDERLESS;
			if (parent.__borderless) flags |= cast WindowFlags.WINDOW_FLAG_BORDERLESS;
			if (Reflect.hasField (parent.config, "depthBuffer") && parent.config.depthBuffer) flags |= cast WindowFlags.WINDOW_FLAG_DEPTH_BUFFER;
			//if (Reflect.hasField (parent.config, "fullscreen") && parent.config.fullscreen) flags |= cast WindowFlags.WINDOW_FLAG_FULLSCREEN;
			if (parent.__fullscreen) flags |= cast WindowFlags.WINDOW_FLAG_FULLSCREEN;
			#if !cairo if (Reflect.hasField (parent.config, "hardware") && parent.config.hardware) flags |= cast WindowFlags.WINDOW_FLAG_HARDWARE; #end
			if (Reflect.hasField (parent.config, "hidden") && parent.config.hidden) flags |= cast WindowFlags.WINDOW_FLAG_HIDDEN;
			if (Reflect.hasField (parent.config, "maximized") && parent.config.maximized) flags |= cast WindowFlags.WINDOW_FLAG_MAXIMIZED;
			if (Reflect.hasField (parent.config, "minimized") && parent.config.minimized) flags |= cast WindowFlags.WINDOW_FLAG_MINIMIZED;
			//if (Reflect.hasField (parent.config, "resizable") && parent.config.resizable) flags |= cast WindowFlags.WINDOW_FLAG_RESIZABLE;
			if (parent.__resizable) flags |= cast WindowFlags.WINDOW_FLAG_RESIZABLE;
			if (Reflect.hasField (parent.config, "stencilBuffer") && parent.config.stencilBuffer) flags |= cast WindowFlags.WINDOW_FLAG_STENCIL_BUFFER;
			if (Reflect.hasField (parent.config, "vsync") && parent.config.vsync) flags |= cast WindowFlags.WINDOW_FLAG_VSYNC;
			if (Reflect.hasField (parent.config, "colorDepth") && parent.config.colorDepth == 32) flags |= cast WindowFlags.WINDOW_FLAG_COLOR_DEPTH_32_BIT;
			
			//if (Reflect.hasField (parent.config, "title")) {
				//
				//title = parent.config.title;
				//
			//}
			
		}
		
		#if (!macro && lime_cffi)
		handle = NativeCFFI.lime_window_create (application.__backend.handle, parent.width, parent.height, flags, title);
		
		if (handle != null) {
			
			parent.__width = NativeCFFI.lime_window_get_width (handle);
			parent.__height = NativeCFFI.lime_window_get_height (handle);
			parent.__x = NativeCFFI.lime_window_get_x (handle);
			parent.__y = NativeCFFI.lime_window_get_y (handle);
			parent.id = NativeCFFI.lime_window_get_id (handle);
			
		}
		
		parent.__scale = NativeCFFI.lime_window_get_scale (handle);
		
		var context = new RenderContext ();
		context.window = parent;
		
		#if hl
		var contextType = @:privateAccess String.fromUTF8 (NativeCFFI.lime_window_get_context_type (handle));
		#else
		var contextType:String = NativeCFFI.lime_window_get_context_type (handle);
		#end
		
		switch (contextType) {
			
			case "opengl":
				
				var gl = new OpenGLRenderContext ();
				
				useHardware = true;
				context.gl = gl;
				context.gles2 = gl;
				context.webgl = gl;
				context.type = gl.type;
				context.version = Std.string (gl.version);
				
				if (gl.type == OPENGLES && gl.version >= 3) {
					
					context.gles3 = gl;
					context.webgl2 = gl;
					
				}
				
				if (GL.context == null) {
					
					GL.context = gl;
					
				}
			
			default:
				
				useHardware = false;
				
				#if lime_cairo
				context.cairo = cairo;
				context.type = CAIRO;
				context.version = "";
				
				parent.context = context;
				render ();
				#end
				context.type = CAIRO;
			
		}
		
		#end
		
		parent.context = context;
		
		setFrameRate (frameRate);
		
	}
	
	
	public function contextFlip ():Void {
		
		#if (!macro && lime_cffi)
		if (!useHardware) {
			
			#if lime_cairo
			if (cairo != null) {
				
				primarySurface.flush ();
				
			}
			#end
			NativeCFFI.lime_window_context_unlock (handle);
			
		}
		
		NativeCFFI.lime_window_context_flip (handle);
		#end
		
	}
	
	
	public function focus ():Void {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_focus (handle);
			#end
			
		}
		
	}
	
	
	public function getDisplay ():Display {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			var index = NativeCFFI.lime_window_get_display (handle);
			
			if (index > -1) {
				
				return System.getDisplay (index);
				
			}
			#end
			
		}
		
		return null;
		
	}
	
	
	public function getDisplayMode ():DisplayMode {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			var data:Dynamic = NativeCFFI.lime_window_get_display_mode (handle);
			displayMode.width = data.width;
			displayMode.height = data.height;
			displayMode.pixelFormat = data.pixelFormat;
			displayMode.refreshRate = data.refreshRate;
			#end
			
		}
		
		return displayMode;
		
	}
	
	
	public function getFrameRate ():Float {
		
		return frameRate;
		
	}
	
	
	public function getEnableTextEvents ():Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			return NativeCFFI.lime_window_get_enable_text_events (handle);
			#end
			
		}
		
		return false;
		
	}
	
	
	public function move (x:Int, y:Int):Void {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_move (handle, x, y);
			#end
			
		}
		
	}
	
	
	public function readPixels (rect:Rectangle):Image {
		
		var imageBuffer:ImageBuffer = null;
		
		switch (parent.context.type) {
			
			case OPENGL:
				
				var gl = parent.context.gl;
				var windowWidth = Std.int (parent.__width * parent.__scale);
				var windowHeight = Std.int (parent.__height * parent.__scale);
				
				var x, y, width, height;
				
				if (rect != null) {
					
					x = Std.int (rect.x);
					y = Std.int ((windowHeight - rect.y) - rect.height);
					width = Std.int (rect.width);
					height = Std.int (rect.height);
					
				} else {
					
					x = 0;
					y = 0;
					width = windowWidth;
					height = windowHeight;
					
				}
				
				var data = new UInt8Array (width * height * 4);
				
				gl.readPixels (x, y, width, height, gl.RGBA, gl.UNSIGNED_BYTE, data);
				
				#if !js // TODO
				
				var rowLength = width * 4;
				var srcPosition = (height - 1) * rowLength;
				var destPosition = 0;
				
				var temp = Bytes.alloc (rowLength);
				var buffer = data.buffer;
				var rows = Std.int (height / 2);
				
				while (rows-- > 0) {
					
					temp.blit (0, buffer, destPosition, rowLength);
					buffer.blit (destPosition, buffer, srcPosition, rowLength);
					buffer.blit (srcPosition, temp, 0, rowLength);
					
					destPosition += rowLength;
					srcPosition -= rowLength;
					
				}
				
				#end
				
				imageBuffer = new ImageBuffer (data, width, height, 32, RGBA32);
			
			default:
				
				#if (!macro && lime_cffi)
				#if !cs
				imageBuffer = NativeCFFI.lime_window_read_pixels (handle, rect, new ImageBuffer (new UInt8Array (Bytes.alloc (0))));
				#else
				var data:Dynamic = NativeCFFI.lime_window_read_pixels (handle, rect, null);
				if (data != null) {
					imageBuffer = new ImageBuffer (new UInt8Array (@:privateAccess new Bytes (data.data.length, data.data.b)), data.width, data.height, data.bitsPerPixel);
				}
				#end
				#end
				
				if (imageBuffer != null) {
					
					imageBuffer.format = RGBA32;
					
				}
			
		}
		
		if (imageBuffer != null) {
			
			return new Image (imageBuffer);
			
		}
		
		return null;
		
	}
	
	
	public function render ():Void {
		
		#if (!macro && lime_cffi)
		NativeCFFI.lime_window_context_make_current (handle);
		
		if (!useHardware) {
			
			#if lime_cairo
			var lock:Dynamic = NativeCFFI.lime_window_context_lock (handle #if hl, { width: 0, height: 0, pixels: 0., pitch: 0 } #end);
			
			if (lock != null && (cacheLock == null || cacheLock.pixels != lock.pixels || cacheLock.width != lock.width || cacheLock.height != lock.height)) {
				
				primarySurface = CairoImageSurface.create (lock.pixels, CairoFormat.ARGB32, lock.width, lock.height, lock.pitch);
				
				if (cairo != null) {
					
					cairo.recreate (primarySurface);
					
				} else {
					
					cairo = new Cairo (primarySurface);
					
				}
				
				parent.context.cairo = cairo;
				
			}
			
			cacheLock = lock;
			#else
			parent.context = null;
			#end
			
		}
		#end
		
	}
	
	
	public function resize (width:Int, height:Int):Void {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_resize (handle, width, height);
			#end
			
		}
		
	}
	
	
	public function setBorderless (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_set_borderless (handle, value);
			#end
			
		}
		
		return value;
		
	}
	
	
	public function setDisplayMode (value:DisplayMode):DisplayMode {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			var data:Dynamic = NativeCFFI.lime_window_set_display_mode (handle, value);
			displayMode.width = data.width;
			displayMode.height = data.height;
			displayMode.pixelFormat = data.pixelFormat;
			displayMode.refreshRate = data.refreshRate;
			#end
			
		}
		
		return displayMode;
		
	}
	
	
	public function setEnableTextEvents (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_set_enable_text_events (handle, value);
			#end
			
			#if android
			if (!value) {
				
				var updateSystemUI = JNI.createStaticMethod ("org/haxe/lime/GameActivity", "updateSystemUI", "()V");
				JNI.postUICallback (function () {
					updateSystemUI ();
				});
				
			}
			#end
			
		}
		
		return value;
		
	}
	
	
	public function setFrameRate (value:Float):Float {
		
		// TODO: Support multiple independent frame rates per window
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_application_set_frame_rate (handle, value);
			#end
			
		}
		
		return frameRate = value;
		
	}
	
	
	public function setFullscreen (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			value = NativeCFFI.lime_window_set_fullscreen (handle, value);
			
			parent.__width = NativeCFFI.lime_window_get_width (handle);
			parent.__height = NativeCFFI.lime_window_get_height (handle);
			parent.__x = NativeCFFI.lime_window_get_x (handle);
			parent.__y = NativeCFFI.lime_window_get_y (handle);
			#end
			
			if (value) {
				
				parent.onFullscreen.dispatch ();
				
			}
			
		}
		
		return value;
		
	}
	
	
	public function setIcon (image:Image):Void {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_set_icon (handle, image.buffer);
			#end
			
		}
		
	}
	
	
	public function setMaximized (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			return NativeCFFI.lime_window_set_maximized (handle, value);
			#end
			
		}
		
		return value;
		
	}
	
	
	public function setMinimized (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			return NativeCFFI.lime_window_set_minimized (handle, value);
			#end
			
		}
		
		return value;
		
	}
	
	
	public function setResizable (value:Bool):Bool {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			NativeCFFI.lime_window_set_resizable (handle, value);
			
			// TODO: remove need for workaround
			
			NativeCFFI.lime_window_set_borderless (handle, !parent.__borderless);
			NativeCFFI.lime_window_set_borderless (handle, parent.__borderless);
			#end
			
		}
		
		return value;
	}
	
	
	public function setTitle (value:String):String {
		
		if (handle != null) {
			
			#if (!macro && lime_cffi)
			return NativeCFFI.lime_window_set_title (handle, value);
			#end
			
		}
		
		return value;
		
	}
	
	
}


@:enum private abstract WindowFlags(Int) {
	
	var WINDOW_FLAG_FULLSCREEN = 0x00000001;
	var WINDOW_FLAG_BORDERLESS = 0x00000002;
	var WINDOW_FLAG_RESIZABLE = 0x00000004;
	var WINDOW_FLAG_HARDWARE = 0x00000008;
	var WINDOW_FLAG_VSYNC = 0x00000010;
	var WINDOW_FLAG_HW_AA = 0x00000020;
	var WINDOW_FLAG_HW_AA_HIRES = 0x00000060;
	var WINDOW_FLAG_ALLOW_SHADERS = 0x00000080;
	var WINDOW_FLAG_REQUIRE_SHADERS = 0x00000100;
	var WINDOW_FLAG_DEPTH_BUFFER = 0x00000200;
	var WINDOW_FLAG_STENCIL_BUFFER = 0x00000400;
	var WINDOW_FLAG_ALLOW_HIGHDPI = 0x00000800;
	var WINDOW_FLAG_HIDDEN = 0x00001000;
	var WINDOW_FLAG_MINIMIZED = 0x00002000;
	var WINDOW_FLAG_MAXIMIZED = 0x00004000;
	var WINDOW_FLAG_ALWAYS_ON_TOP = 0x00008000;
	var WINDOW_FLAG_COLOR_DEPTH_32_BIT = 0x00010000;
	
}