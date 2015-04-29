package {
	
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.net.FileReference;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	
	[SWF(width='768',height='500',frameRate="60")]
	
	public class Main extends Sprite {
		
		[Embed(source="../lib/movieBytes",mimeType="application/octet-stream")]
		private const movieBytes:Class;
		
		static private const SWF_URL:String = "test.swf";
		static private const MOVIE_NAME:String = "movie";
		
		static private var DATA:ByteArray;
		
		public function Main() {
			
			// test
			//DATA = new movieBytes();
			//DATA.inflate();
			//printHeader(DATA);
			
			
			// init parser
			load();
		
		}
		
		private function load():void {
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, loaderComplete);
			loader.load(new URLRequest(SWF_URL));
		}
		
		private var swf:MovieClip;
		
		private function loaderComplete(e:Event):void {
			var clazz:Class = e.target.content.loaderInfo.applicationDomain.getDefinition(MOVIE_NAME);
			swf = new clazz() as MovieClip;
			
			encode(swf);
			
			// utils
			//printHeader(DATA);
			//printObjects(DATA, 1);
			
			save(DATA);
		
		}
		
		private function getProps(movie:Object):Object {
			const s:String = String(movie.bitmapData).slice(8, String(movie.bitmapData).length - 1);
			var objResult:Object = {name: s, alpha: 1.0, matrix: new Matrix()};
			function step(movie:Object):void {
				objResult.alpha *= movie.alpha;
				objResult.matrix.concat(movie.transform.matrix);
				if (movie.parent) {
					step(movie.parent);
				}
			}
			step(movie);
			
			return objResult;
		}
		
		private var childPropsList:Vector.<Object> = new <Object>[];
		
		private function getChild(movie:Object):void {
			var i:uint = 0, nc:uint = movie.numChildren, temp:Object, tData:Object;
			for (; i < nc; i++) {
				temp = movie.getChildAt(i);
				if (temp.hasOwnProperty("numChildren")) {
					getChild(temp);
				} else {
					tData = getProps(temp);
					childPropsList.push({ //
							name: tData.name, //
							alpha: tData.alpha, //
							matrix: tData.matrix //
						});
				}
			}
			if (movie.currentFrame == movie.totalFrames) {
				movie.gotoAndStop(1);
			} else
				movie.nextFrame();
		}
		
		private function encode(movie:Object):void {
			
			var header:ByteArray = new ByteArray(), //
				props:ByteArray = new ByteArray(), //
				frameRegisterTotal:ByteArray = new ByteArray(), //
				frtCount:int = 0, //
				frameRegister:ByteArray, tf:uint = movie.totalFrames, //
				count:uint = 0;
			
			//trace("\ntotalFrames:", movie.totalFrames);
			header.writeInt(movie.totalFrames);
			
			function step(movie:Object):void {
				
				//trace("\nframe:", movie.currentFrame, PROPS.position);
				header.writeUnsignedInt(props.position);
				
				childPropsList.length = 0;
				
				getChild(movie);
				
				var i:uint = 0, //
					len:uint = childPropsList.length, //
					childPropTemp:Object, //
					tname:String, //
					rname:String, //
					rcount:int = 0, //
					registerNewFlag:Boolean, //					
					frName:String, //
					frCount:int;
				
				//trace("numObjects:", len);				
				
				frameRegister = new ByteArray();
				
				for (; i < len; i++) {
					childPropTemp = childPropsList[i];
					
					tname = childPropTemp.name;
					registerNewFlag = true;
					
					//trace(childPropTemp.name, childPropTemp.alpha, childPropTemp.matrix);
					
					// register textures at this frame
					frameRegister.position = 0;
					while (frameRegister.bytesAvailable) {
						rname = frameRegister.readUTF();
						rcount = frameRegister.readUnsignedInt();
						if (tname == rname) {
							frameRegister.position -= 4;
							frameRegister.writeUnsignedInt(++rcount);
							registerNewFlag = false;
							break;
						}
					}
					if (registerNewFlag) {
						frameRegister.writeUTF(tname);
						frameRegister.writeUnsignedInt(1);
					}
					
					props.writeUTF(tname);
					props.writeDouble(childPropTemp.alpha);
					props.writeDouble(childPropTemp.matrix.a);
					props.writeDouble(childPropTemp.matrix.b);
					props.writeDouble(childPropTemp.matrix.c);
					props.writeDouble(childPropTemp.matrix.d);
					props.writeDouble(childPropTemp.matrix.tx);
					props.writeDouble(childPropTemp.matrix.ty);
					
				}
				
				// compare frame registers
				frameRegister.position = 0;
				while (frameRegister.bytesAvailable) {
					frName = frameRegister.readUTF();
					frCount = frameRegister.readUnsignedInt();
					registerNewFlag = true;
					frameRegisterTotal.position = 0;
					while (frameRegisterTotal.bytesAvailable) {
						rname = frameRegisterTotal.readUTF();
						rcount = frameRegisterTotal.readUnsignedInt();
						if (frName == rname) {
							frameRegisterTotal.position -= 4;
							frameRegisterTotal.writeUnsignedInt(((frCount > rcount) ? frCount : rcount));
							registerNewFlag = false;
							break;
						}
					}
					if (registerNewFlag) {
						frameRegisterTotal.writeUTF(frName);
						frameRegisterTotal.writeUnsignedInt(frCount);
						++frtCount;
					}
				}
				
				header.writeUnsignedInt(props.position);
				header.writeUnsignedInt(len);
				
				if (++count < tf) {
					step(movie);
				}
			}
			
			step(movie);
			
			//trace("numTextures", frtCount, "\n");
			//frameRegisterTotal.position = 0;
			//while (frameRegisterTotal.bytesAvailable) {
			//trace(frameRegisterTotal.readUTF(), frameRegisterTotal.readUnsignedInt());
			//}			
			
			DATA = new ByteArray();
			DATA.writeInt(frtCount);
			DATA.writeBytes(frameRegisterTotal, 0, frameRegisterTotal.length);
			DATA.writeUnsignedInt(header.position + frameRegisterTotal.length);
			DATA.writeBytes(header, 0, header.length);
			DATA.writeBytes(props, 0, props.length);
		
		}
		
		private function save(bytes:ByteArray):void {
			bytes.position = 0;
			bytes.deflate();
			var file:FileReference = new FileReference();
			file.save(bytes);
		}
		
		// get movie
		//private function getStarlingMovie(bytes:ByteArray, complete:Function):void {
		//
		//// init		
		//var render:RenderTexture;
		//var img:Image;
		//var container:Sprite;
		//var textures:Vector.<Texture>;
		//var movie:AssukarMovieClip;
		//
		//// process
		//bytes.position = 0;			
		//var numTextures:int = bytes.readInt();
		//while (numTextures--) {
		//bytes.readUTF();
		//bytes.readUnsignedInt();
		//}				
		//const hl:uint = bytes.readUnsignedInt(), //
		//tf:int = bytes.readInt();
		//
		//textures = new <Texture>[];
		//
		//var i:int, //
		//start:uint, //
		//end:uint, //
		//headerLen:uint, //
		//frameCount:uint, //
		//totalFrames:uint;
		//
		//i = 1;
		//for (; i <= tf; i++) {
		//bytes.position = 0;				
		//var numTextures:int = bytes.readInt();
		//while (numTextures--) {
		//bytes.readUTF();
		//bytes.readUnsignedInt();
		//}					
		//headerLen = bytes.readUnsignedInt() + 8;
		//frameCount = 0;
		//totalFrames = bytes.readInt();
		//if (i < 1 || i > totalFrames) {
		//return;
		//}
		//while (bytes.position < headerLen) {
		//++frameCount;
		//start = bytes.readUnsignedInt() + headerLen;
		//end = bytes.readUnsignedInt() + headerLen;
		//bytes.readUnsignedInt();
		//if (i == frameCount) {
		//break;
		//}
		//}
		//if (container) {
		//container.removeChildren(0, -1, true);
		//}
		//container = new Sprite();
		//bytes.position = start;
		//while (bytes.position < end) {
		//if (img) {
		//img.texture.dispose();
		//img.dispose();
		//img = null;
		//}
		//img = new Image(JeriAssets.ME.texture(bytes.readUTF()));
		//img.smoothing = TextureSmoothing.TRILINEAR;
		//img.alpha = bytes.readDouble();
		//img.transformationMatrix = new Matrix( //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble() //
		//);
		//container.addChild(img);
		//}
		//render = new RenderTexture(400, 400, false);
		//render.draw(container);
		//textures.push(render);
		//}
		//
		//// create movie
		//movie = new AssukarMovieClip(textures);
		//
		//// dispose temps
		//render.dispose();
		//container.removeChildren(0, -1, true);
		//textures.length = 0;
		//
		//// return
		//complete(movie);
		//}
		
		
		
		
		//var c:Component = new Component();
		//const bytes:ByteArray = new movieBytes();
		//bytes.inflate();
		//printHeader(bytes);		
		//printObjects(bytes, 1); 	
		
		// starling movie
		//getStarlingMovie(bytes, function(m:AssukarMovieClip):void {		
		//c.addObject(m);
		//c.playAnima(m);
		//}); 	
		
		
		
		
		// assukar movie		
		//var dicName:ByteArray = new ByteArray();
		//var objList:Vector.<Vector.<Image>> = new < Vector.<Image> > [];			
		//
		//bytes.position = 0;
		//var numTextures:int = bytes.readInt(), //
		//tname:String, //
		//tlen:uint, //
		//i:int = 0, //
		//j:int = 0;
		//
		//for (; i < numTextures; i++) {
		//tname = bytes.readUTF();
		//tlen = bytes.readUnsignedInt();
		//objList[i] = new <Image>[];
		//
		//dicName.writeUTF(tname);
		//dicName.writeUnsignedInt(i);
		//
		//j = 0;
		//for (; j < tlen; j++) {
		//objList[i][j] = c.addImage(JeriAssets.ME.texture(tname));
		//}
		//}
		//
		//function getIndexByName(name:String):int {
		//var tname:String, //
		//tindex:uint;
		//dicName.position = 0;
		//while (dicName.bytesAvailable) {
		//tname = dicName.readUTF();
		//tindex = dicName.readUnsignedInt();
		//if (name == tname) {
		//return tindex;
		//}
		//}
		//return -1;
		//}
		//
		//function hideAll():void {
		//var i:int = 0, //
		//ilen:int = objList.length, //
		//jlen:int, //
		//j:int;
		//for (; i < ilen; i++) {
		//j = 0;
		//jlen = objList[i].length;
		//for (; j < jlen; j++) {
		//c.hide(objList[i][j]);
		//}
		//}
		//}
		//
		//function gotoFrame(frame:int):void {
		//hideAll();
		//var start:uint, end:uint;
		//bytes.position = 0;
		//var numTextures:int = bytes.readInt();
		//while (numTextures--) {
		//bytes.readUTF();
		//bytes.readUnsignedInt();
		//}
		//const headerLen:uint = bytes.readUnsignedInt() + 8;
		//var frameCount:uint = 0;
		//var totalFrames:uint = bytes.readInt();
		//if (frame < 1 || frame > totalFrames) {
		//return;
		//}
		//while (bytes.position < headerLen) {
		//++frameCount;
		//start = bytes.readUnsignedInt() + headerLen;
		//end = bytes.readUnsignedInt() + headerLen;
		//bytes.readUnsignedInt();
		//if (frame == frameCount) {
		//break;
		//}
		//}
		//
		//var objName:String;
		//var objIndex:int;
		//var obj:Image;
		//var objLen:int = 0;
		//var prevObjName:String;
		//
		//bytes.position = start;
		//while (bytes.position < end) {
		//
		//objName = bytes.readUTF();
		//objIndex = getIndexByName(objName);
		//
		//if (prevObjName != objName) {
		//prevObjName = objName;
		//objLen = objList[objIndex].length - 1;
		//}
		//
		//obj = objList[objIndex][objLen--];
		//
		//c.show(obj);
		//c.setChildIndex(obj, numTextures - 1);
		//
		//obj.alpha = bytes.readDouble();
		//obj.transformationMatrix = new Matrix( //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble(), //
		//bytes.readDouble() //
		//);
		//
		//}
		//
		//}
		//
		//var frameObject:Object = {frame: 1};
		//var temp:uint;
		//AssukarJuggler.ME.tween(frameObject, 0.033 * 70, { // 
		//frame: 71, //
		//repeatCount: int.MAX_VALUE, //
		//onUpdate: function():void {
		//temp = frameObject.frame;
		//gotoFrame(temp);
		//}});
		//
		//v.push(c);
		
		
		
		//utils
		private function printHeader(bytes:ByteArray):void {
			bytes.position = 0;
			
			var numTextures:int = bytes.readInt();
			trace("numTextures", numTextures);
			while (numTextures--) {
				trace(bytes.readUTF(), bytes.readUnsignedInt());
			}
			
			const headerLen:uint = bytes.readUnsignedInt();
			trace("\ntotalFrames:", bytes.readInt());
			var frameCount:uint = 0;
			while (bytes.position < headerLen) {
				trace("frame:", ++frameCount, //
					", props range:", bytes.readUnsignedInt(), "-", bytes.readUnsignedInt(), //
					", numObjects:", bytes.readUnsignedInt() //
					);
			}
		}
		
		private function printObjects(bytes:ByteArray, frame:int):void {
			trace("\nframe", frame);
			var start:uint, end:uint;
			bytes.position = 0;
			var numTextures:int = bytes.readInt();
			while (numTextures--) {
				bytes.readUTF();
				bytes.readUnsignedInt();
			}
			const headerLen:uint = bytes.readUnsignedInt() + 8;
			var frameCount:uint = 0;
			var totalFrames:uint = bytes.readInt();
			if (frame < 1 || frame > totalFrames) {
				return;
			}
			while (bytes.position < headerLen) {
				++frameCount;
				start = bytes.readUnsignedInt() + headerLen;
				end = bytes.readUnsignedInt() + headerLen;
				bytes.readUnsignedInt();
				if (frame == frameCount) {
					break;
				}
			}
			bytes.position = start;
			while (bytes.position < end) {
				trace("name", bytes.readUTF());
				trace("alpha", bytes.readDouble());
				trace("a", bytes.readDouble());
				trace("b", bytes.readDouble());
				trace("c", bytes.readDouble());
				trace("d", bytes.readDouble());
				trace("tx", bytes.readDouble());
				trace("ty", bytes.readDouble());
			}
		}
	
	}

}