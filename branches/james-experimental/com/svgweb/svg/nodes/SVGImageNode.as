/*
Copyright (c) 2008 James Hight
Copyright (c) 2008 Richard R. Masters, for his changes.

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
*/

package com.svgweb.svg.nodes
{
	import com.svgweb.svg.core.SVGNode;
	import com.svgweb.svg.utils.Base64;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.geom.Matrix;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.utils.*;
    
    public class SVGImageNode extends SVGNode
    {        
        private var bitmap:Bitmap;
        private var urlLoader:URLLoader;
        
        public var imageWidth:Number = 0;
        public var imageHeight:Number = 0;
                   
        public function SVGImageNode(svgRoot:SVGSVGNode, xml:XML = null, original:SVGNode = null):void {
            super(svgRoot, xml, original);
        }  
         
        
        override public function drawNode(event:Event=null):void {
        	this.removeEventListener(Event.ENTER_FRAME, drawNode); 
            
            this._firstX = true;
            this._firstY = true;
            
            this.clearMask();
            
            this.transform.matrix = new Matrix();
            
            this.setAttributes();
            this.transformNode();
            this.generateGraphicsCommands();
            this.draw();
            
            //The rest is handled after image is loaded
            /* this.applyViewBox();
            this.maskNode();
            
            this.svgRoot.doneRendering(); */
        }
        
        private function finishDrawNode():void {
        	this.applyViewBox();
            this.maskNode();
            this.createMask();            
            
            this._invalidDisplay = false;
            this.svgRoot.doneRendering(); 
        }
        
        override protected function draw():void {
            var imageHref:String = this.getAttribute('href');
            
            if (!imageHref) {
                return;
            }

            // For data: href, decode the base 64 image and load it
            if (imageHref.match(/^data:[a-z\/]*;base64,/)) {
                var base64String:String = imageHref.replace(/^data:[a-z\/]*;base64,/, '');                
                var byteArray:ByteArray = Base64.decode(base64String);                
                loadBytes(byteArray);    
                return;            
            }
            
            //Url doesn't have to have http:
            //it could be relative
            if (this._xml.@width && this._xml.@height) {
                urlLoader = new URLLoader();
                urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
                
                urlLoader.addEventListener(Event.COMPLETE, onURLLoaderComplete);
                
                urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onError);
                urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
                
                urlLoader.load(new URLRequest(imageHref));
            }
        }
        
        override protected function applyViewBox():void {
        	       
            var canvasWidth:Number = this.getWidth();
            var canvasHeight:Number = this.getHeight();                
            
            if ((canvasWidth > 0)
                && (canvasHeight > 0)) { 
                	
                var cropWidth:Number;
                var cropHeight:Number;   
                	                
                var oldAspectRes:Number = this.imageWidth / this.imageHeight;   
                var newAspectRes:Number = canvasWidth /  canvasHeight;             
                
                var preserveAspectRatio:String = this.getAttribute('preserveAspectRatio', 'xMidYMid meet', false);;               
                var alignMode:String = preserveAspectRatio.substr(0,8);
                
                var meetOrSlice:String = 'meet';
                if (preserveAspectRatio.indexOf('slice') != -1) {
                    meetOrSlice = 'slice';
                }
                
                if (alignMode == 'none') {
                    // stretch to fit viewport width and height
                    cropWidth = canvasWidth;
                    cropHeight = canvasHeight;
                }
                else {
                    if (meetOrSlice == 'meet') {
                        // shrink to fit inside viewport

                        if (newAspectRes > oldAspectRes) {
                            cropWidth = canvasHeight * oldAspectRes;
                            cropHeight = canvasHeight;
                        }
                        else {
                            cropWidth = canvasWidth;
                            cropHeight = canvasWidth / oldAspectRes;
                        }
    
                    }
                    else {
                        // meetOrSlice == 'slice'
                        // Expand to cover viewport.

                        if (newAspectRes > oldAspectRes) {
                            cropWidth = canvasWidth;
                            cropHeight = canvasWidth / oldAspectRes;
                        }
                        else {
                            cropWidth = canvasHeight * oldAspectRes;
                            cropHeight = canvasHeight;
                        }
    
                    }
                }
                
                this.bitmap.scaleX = cropWidth / this.imageWidth;
                this.bitmap.scaleY = cropHeight / this.imageHeight;
                

                var borderX:Number;
                var borderY:Number;
                var translateX:Number;
                var translateY:Number;
                if (alignMode != 'none') {
                    translateX=0;
                    translateY=0;
                    var xAlignMode:String = alignMode.substr(0,4);
                    switch (xAlignMode) {
                        case 'xMin':
                            break;
                        case 'xMax':
                            translateX = canvasWidth - cropWidth;
                            break;
                        case 'xMid':
                        default:
                            borderX = canvasWidth - cropWidth;
                            translateX = borderX / 2.0;
                            break;
                    }
                    var yAlignMode:String = alignMode.substr(4,4);
                    switch (yAlignMode) {
                        case 'YMin':
                            break;
                        case 'YMax':
                            translateY = canvasHeight - cropHeight;
                            break;
                        case 'YMid':
                        default:
                            borderY = canvasHeight - cropHeight;
                            translateY = borderY / 2.0;
                            break;
                    }
                    this.bitmap.x = translateX;
                    this.bitmap.y = translateY;
                } 
                                  
            }               
        
        }
        
        private function onError(event:Event):void {
        	//this.dbg("IOError: " + event.text);
        	this.finishDrawNode();
        	urlLoader = null;
        }        
        
        private function onURLLoaderComplete( event:Event ):void {
            this.loadBytes(ByteArray(urlLoader.data));
            urlLoader = null;
        }
        
        /**
         * Load image byte array
         * Used to support data: href.
         **/
        private function loadBytes(byteArray:ByteArray):void {            
            var loader:Loader = new Loader();
            loader.contentLoaderInfo.addEventListener( Event.COMPLETE, onBytesLoaded );            
            loader.loadBytes( byteArray );                
        }
         
        
        /**
         * Display image bitmap once bytes have loaded 
         * Used to support data: href.
         **/
        private function onBytesLoaded( event:Event ) :void
        {
            var content:DisplayObject = LoaderInfo( event.target ).content;
            var bitmapData:BitmapData = new BitmapData( content.width, content.height, true, 0x00000000 );
            bitmapData.draw( content );
            
            
            this.imageWidth = bitmapData.width;
            this.imageHeight = bitmapData.height;
            
            bitmap = new Bitmap( bitmapData );
            bitmap.opaqueBackground = null;
            this.addChild(bitmap);            

            this.finishDrawNode();
            
        }                
         
    }
}
