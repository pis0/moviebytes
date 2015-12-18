package
{
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.net.FileReference;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.ByteArray;
	
	[SWF(width = '500', height = '300', backgroundColor = "0xe1e1e1", frameRate = "60")]
	
	public class Fix extends Sprite
	{
		
		public function Fix()
		{
			
			this.addChild(createDisplay());
			
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			stage.addEventListener(MouseEvent.MOUSE_UP, function():void{
				loadBtnLabel.y = 0;
			});
			
			stage.addEventListener(Event.RESIZE, function():void { 
				output.width = stage.stageWidth - output.x  - 20;
				output.height = stage.stageHeight - output.y  - 20;
			});
		
		}
		
		// display
		private var display:Sprite;
		
		private function createDisplay():Sprite
		{
			display = new Sprite();
			display.addChild(createLoadBtn());
			//display.addChild( createMovieNameInput() );	
			//display.addChild( createEncodeBtn() );
			display.addChild( createOutput() );
			
			return display;
		}
		
		
		private var output:TextField
		private function createOutput():TextField {
			output = new TextField();			
			output.border = output.background = true;
			output.backgroundColor = 0xffffff;
			
			output.x = 200;
			output.y = 20;
			
			
			return output;
		}
		
		
		
		private var loadBtn:Sprite;
		private var loadBtnLabel:TextField;
		
		private function createLoadBtn():Sprite
		{
			loadBtn = new Sprite();
			
			loadBtnLabel = new TextField();
			
			loadBtnLabel.defaultTextFormat = new TextFormat("Arial", 12, null, null, null, null, null, null, "center");
			loadBtnLabel.text = "LOAD BYTES";
			loadBtnLabel.width = 160;
			loadBtnLabel.height = 20;
			loadBtnLabel.border = loadBtnLabel.background = true;
			loadBtnLabel.backgroundColor = 0xffffff;
			loadBtnLabel.mouseEnabled = loadBtnLabel.selectable = false;
			
			loadBtn.addChild(loadBtnLabel);
			loadBtn.buttonMode = true;
			loadBtn.addEventListener(MouseEvent.MOUSE_DOWN, function():void
			{
				loadBtnLabel.y = 2;
				load();
			});
			
			loadBtn.x = 20;
			loadBtn.y = 20;
			
			return loadBtn;
		}
		
		private var file:FileReference;
		private var input:ByteArray;
		
		private function load():void
		{
			file = new FileReference();
			file.browse();
			file.addEventListener(Event.SELECT, function(e:Event):void
			{
				output.text = "";
				loadBtnLabel.y = 0;
				
				file.load();
				file.addEventListener(Event.COMPLETE, function():void
				{
					input = file.data as ByteArray;
					input.inflate();
					
					fix(); 
				});
			});
		}
		
		
		
		private function fix():void
		{
			
			
			//output.appendText("\nChecking...");  
			//if (check()) 
			//{
				//output.appendText("\nOK!");  
				//return; 
			//}
			
			//trace("ERROR! (fixing...)");  	
			output.appendText("\nERROR! (fixing...)");  	
			
			
			input.position = 0;
			
			//
			var numTextures:int = input.readInt();
			
			//trace("\nnumTextures", numTextures);
			output.appendText("\nnumTextures " + numTextures);
			
			//
			var i:int = 0;
			var tname:String;
			var tlen:uint;
			for (; i < numTextures; i++)
			{
				tname = input.readUTF();
				tlen = input.readUnsignedInt();
				
				//trace("name", tname , " - qtd", tlen); 
				output.appendText("\nname " + tname + "  - qtd " + tlen); 				
			}
			
			//
			var headerLen:uint = input.readUnsignedInt() + 8;
			
			//trace("\nheaderLen", headerLen);
			output.appendText("\n\nheaderLen " + headerLen);
			
			//
			var totalFrames:int = input.readInt();
			
			//trace("\ntotalFrames", totalFrames); 
			output.appendText("\n\ntotalFrames " + totalFrames); 			
			
			//			
			var tempProps:ByteArray = new ByteArray(); 
			var tempHeader:ByteArray = new ByteArray(); 
			
			var frameCount:uint = 0;
			var pointer:uint; 
			while (input.position < headerLen)
			{
				
				var start:uint = input.readUnsignedInt();
				var end:uint = input.readUnsignedInt();
				var numObjects:uint = input.readUnsignedInt();
				
				//trace("frame:", ++frameCount, ", props range:", start, "-", end, ", numObjects:", numObjects);
				output.appendText("\nframe: " + (++frameCount) + " , props range: " + start + " - " + end + " , numObjects: " + numObjects);				
				
				
				pointer = input.position;
				
					var objCounter:uint = 0;
					
					tempHeader.writeUnsignedInt(tempProps.position); 
					
					input.position = start + headerLen;			
					while (input.position < end + headerLen) 
					{							
						tempProps.writeUTF(input.readUTF());
						tempProps.writeDouble(input.readDouble());				
						tempProps.writeDouble(input.readDouble());
						tempProps.writeDouble(input.readDouble());
						tempProps.writeDouble(input.readDouble());
						tempProps.writeDouble(input.readDouble());
						tempProps.writeDouble(input.readDouble());
						tempProps.writeDouble(input.readDouble());							
						tempProps.writeUnsignedInt(0); 	
						
						++objCounter;
					}
					
					tempHeader.writeUnsignedInt(tempProps.position); 
					tempHeader.writeUnsignedInt(objCounter); 					
					
				
				
				input.position = pointer; 
				
			} 
			
				
				input.position = 0;
				input.readInt();
				while (numTextures--) 
				{
					input.readUTF();
					input.readUnsignedInt();
				}
				input.readUnsignedInt();
				input.readInt();				
				input.writeBytes(tempHeader, 0, tempHeader.length);				
				
				input.position = headerLen;		 				
				input.writeBytes(tempProps, 0, tempProps.length); 	
				
				
				//trace("FIXED!\n");
				output.appendText("\nFIXED!\n"); 
				
				save(input); 
			
			
			
			
			
			
			
		}
		
		
		
		//private function check():Boolean
		//{
			//input.position = 0;
			//
			////
			//var numTextures:int = input.readInt();
			//
			////
			//var i:int = 0;
			//var tname:String;
			//var tlen:uint;
			//for (; i < numTextures; i++)
			//{
				//tname = input.readUTF();
				//tlen = input.readUnsignedInt();			
			//}
			//
			////
			//var headerLen:uint = input.readUnsignedInt() + 8;
			//
			////
			//var totalFrames:int = input.readInt();			
			//
			////			
			//var tempProps:ByteArray = new ByteArray(); 
			//var tempHeader:ByteArray = new ByteArray(); 
			//
			//var frameCount:uint = 0;
			//var pointer:uint; 
			//while (input.position < headerLen)
			//{
				//
				//var start:uint = input.readUnsignedInt();
				//var end:uint = input.readUnsignedInt();
				//var numObjects:uint = input.readUnsignedInt();				
				//
				//pointer = input.position;
				//
				////
				//try
				//{
					//input.position = start + headerLen;			
					//while (input.position < end + headerLen) 
					//{										
						//input.readUTF();
						//input.readDouble();				
						//input.readDouble();
						//input.readDouble();
						//input.readDouble();
						//input.readDouble();
						//input.readDouble();
						//input.readDouble();				
						//input.readUnsignedInt(); 
					//}					
				//}
				//catch (err:Error)			
				//{
					//trace("PLAU!");
					//return false;
				//}
			//}
			//
			//
			//return true;
		//}
		
		
		
		
		
		private function save(bytes:ByteArray):void {
			bytes.position = 0;
			bytes.deflate();
			var f:FileReference = new FileReference();
			f.save(bytes, file.name);  
		}
		
		
		
	
	}

}