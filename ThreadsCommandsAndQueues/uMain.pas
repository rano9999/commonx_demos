unit uMain;

interface
{x$DEFINE TI}//USE TYPE INFERENCE

uses
  stringx, tickcount, systemx,typex, Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, FrameTotalDebug, simplequeue, commandprocessor, anoncommand, globalmultiqueue, better_collections, linked_list,
  Vcl.Imaging.jpeg, fastbitmap, easyimage, debug, pngimage;

const
  MIN_PRIME = 1000000000;
  MAX_PRIME = 1000001000;

type
  //-----------------------------------
  //TWO FLAVORS OF THE SAME ICE-CREAM
  //below are
  // - a sample QueueItem (lightweight)
  // - a sample Command (smarter)
  //Which should you choose?
  // - QueueItems are lightweight enough to be used for fairly simple things
  //   e.g., I have used them for
  //     -- Individual disk reads
  //     -- Individual UDP Packet sends and reads
  // - Commands are better for heavier things (perferably ones that take a little time)
  //     -- File Compressions/Conversions
  //     -- File copies/moves
  //     -- HTTP downloads

  // TSimpleQueue PROS and CONS
  //   - DUMBER: Better for lightweight things. A single TSimpleQueue is a single threaded construct, items added to it
  //     are processed in order. If you want multi-threaded distribution of QueueItems, use TMultiqueue
  //     which is essentially a collection of TSimpleQueues (one for each CPU core)
  //     There can only be one active queueitem per core per multi-queue
  //     but this super-simple approach makes it lightweight enough for quick tasks.
  //
  // TCommandProcessor PROS and CONS
  //   - SMARTER:
  //     Resource allocation: is handled on-demand for commands and commands
  //      are not limited to 1-command per core.
  //
  //      TCommandProcessor attempts to run all active commands in the most efficient
  //      order possible.  For example, if you have 4 COREs, you could
  //      run 4 commands simultaneously that are 100% CPU Intensive, but if you have
  //      more commands active that are 0% CPu intense, but rather consume some other
  //      resource, such as memory or network, TCommandProcessor is smart enough to
  //      allow those commands to proceed simultaneously as well.
  //
  //     Dependencies:  Commands can have dependencies on other commands which
  //                    controls the order in which they get executed.

  //   - OVERBUILT for many tasks: TCommandProcessor is very overbuilt
  //      for simple tasks.  But this overbuilding
  //     has some benefits.

  TQueueItem_IsPrime = class(TQueueItem)
    //Creating a queue items is EASY AF
    //Just override DoExecute
    //Also add any publics you might want to set before calling start()
    //or retrieve after the command is finished.
  protected
    procedure DoExecute; override;
  public
    in_n: ni;//this is the prime we are testing
    out_isPrime: boolean;//this is returned, is it Prime or not?
  end;

  TCommand_IsPrime = class(TCommand)
    //Creating a command is EASY AF
    //Just override DoExecute
    //Also add any publics you might want to set before calling start()
    //or retrieve after the command is finished.
  protected
    procedure DoExecute; override;
    //optionally override -- procedure InitExpense;override;
    //to set Initial expense for your command (CPUExpense, MemoryExpense, etc)
  public
    in_n: ni;//this is the prime we are testing
    out_isPrime: boolean;//this is returned, is it Prime or not?
  end;

  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------
  //----------------------------------------------------------------------------


  TForm1 = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    panFrameHost: TPanel;
    Splitter1: TSplitter;
    btnQueues: TButton;
    lblResult: TLabel;
    tmCheckCommand: TTimer;
    lblResult2: TLabel;
    btnCommands: TButton;
    Image1: TImage;
    Button1: TButton;
    cbTryOpenCL: TCheckBox;
    Label1: TLabel;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnQueuesClick(Sender: TObject);
    procedure lblResultClick(Sender: TObject);
    procedure tmCheckCommandTimer(Sender: TObject);
    procedure TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure btnCommandsClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    activecmd: TCommand;
    { Private declarations }
  public
    tmStart: ticker;
    { Public declarations }
    procedure RefreshProcInfo;
    procedure UpdateState;
    procedure TileNotify(src, dest: TFastBitmap; region: TPixelRect; state: TTileState);
  end;


function CheckIsPrime(n: int64; p: PProgress): boolean;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.btnQueuesClick(Sender: TObject);
  //The following example tests for primes in the range of MIN_PRIME to MAX_PRIME
  //using TQueueItem_IsPrime.

  //in a nutshell, what happens here is we create a QueueItem
  // for each prime number we want to test and then add them to the
  // "Global multi Queue" GMQ.
 //
  //This differs from the Command sample internally.
  //The Multiqueue is essentially a round-robin set of queues...
  // one for each logical CPU core.
  //The work is added to the queues in a brute force manner and each
  // queue works independently to clear out it's backlog.
  //This means that if there are items in the queues that take
  // an uncertain/uneven amount of time, one queue could grow longer
  // than the others and resource usage balance could be affected.
  //
  //However, if you want to create a whole bunch of simple tasks with minimal
  // overhead, this is the construct to use.


var
  ac: TAnonymousCommand<ni>;
  res: ni;
  tmStart,tmEnd: ticker;
begin
  //
  res := 0;
  RefreshProcInfo;

  tmStart := getticker;

  ac := TAnonymousCommand<ni>.create(
          function: ni
          var
            x: ni;
            qi: TQueueItem_IsPrime;
          begin
            res := 0;
            ac.Status := 'Creating Queue Items';
            ac.Step := 0;
            ac.StepCount := MAX_PRIME-MIN_PRIME;
            for x := MIN_PRIME to MAX_PRIME do begin
              if (x and 1)=0 then continue;//skip evens
              ac.Step := x-MIN_PRIME;
              qi := TQueueItem_IsPrime.create;
              qi.in_n := x;
              GMQ.AddItem(qi);
              qi.autodestroy := true;
              qi.onFinish_Anon := ( procedure (qilocal: TQueueItem)
                                begin
                                  if (qilocal as TQueueItem_IsPrime).out_isPrime then
                                    inc(res);
                                end
              );

            end;
            GMQ.WaitForAllQueues;
          end
          ,
          procedure(result: ni)
          begin
            GMQ.WaitForAllQueues;
            tmEnd := gettimesince(tmStart);
            lblResult.caption := 'Found '+inttostr(res)+' primes in '+floatprecision(tmEnd/1000,3)+' seconds.';

          end,
          procedure(e: Exception)
          begin
            raise e;

          end
          , true, false
        );
  ac.SynchronizeFinish := true;
  ac.start;
  activecmd := ac;




end;

procedure TForm1.Button1Click(Sender: TObject);
//The following code shows how to interact with TFastBitmap's muilti-threaded
//iterator.
//The iterator automatically handles dividing up image processing work
//among threads and CPU cores.
//
//In a nutshell.  We start with an existing image, create an output image for the
//result and then run the iterator with an anonymous function that tells
//it how the output should manipulate the source.
//
//This demo performs a heavy blur on the source.
//
//As each region of the bitmap is calculated, TileNotify() is called via Synchronize()
//which allows us to see the result as they are produced.
//use of TileNotify() is totally optional (mostly it is there just for eye candy)
//and the result of the operation will be a fully merged TFastBitmap.
//

const
  BLUR_RADIUS = 16;
var
  src: TFastBitmap;
  dest: TFastBitmap;
  jpg: TJPEGImage;
  bitmap: TBitmap;
  opencl_code: string;
begin

  tmStart := getTicker;
  //make a fast bitmap from the image component
  src := TFastBitmap.create;

  //------------------------------------------
  //Since use of TileNotify() draws on a bitmap canvas, it only works if we have a windows TBitmap
  //loaded into the TImage. (else it does bascally nothing)
  //TODO 1: Make it easier to get the graphic type we want
  //The following code checks the graphic type and converts them to what we want.
  Debug.Log(image1.picture.graphic.ClassName);
  //-- if we have a JPEG in the TImage
  if image1.picture.graphic is TJPEGImage then begin
    //convert the JPeg into a Bitmap.
    bitmap := jpegToBitmap(image1.picture.graphic as TJpegImage, true);
    try
      //use the bitmap as the basis for our TfastBitmap source
      src.FromBitmap(bitmap);
      image1.picture.assign(bitmap);
    finally
      bitmap.free;
    end;
  end else
  if image1.picture.graphic is TPNGImage then begin
    src.FromPNG(image1.picture.graphic as TPNGImage);
  end else begin
    src.FromBitmap(image1.picture.graphic as TBitmap);
  end;

  //------------------------------------------
  //make the destination
  dest := TFastBitmap.create;
  //set destination to same dimensions as source
  dest.width := src.width;
  dest.height := src.height;
  //new, blank bitmap
  dest.New;

  if cbTryopenCL.checked then begin
    //including openCL code is optional, but very powerful for many workloads
    opencl_code :=
            '__kernel void main('+CRLF+
                  '__global uchar4* dst, '+CRLF+//  AddOutput(dest.ptr, dest.sz);
                  '__global long* dst_width, '+CRLF+
                  '__global long* dst_height,'+CRLF+
                  '__global long* dst_stride_in_pixels, '+CRLF+
                  '__global uchar4* src,'+CRLF+//  AddInput(src.ptr, src.sz);
                  '__global long* src_width,'+CRLF+
                  '__global long* src_height,'+CRLF+
                  '__global long* src_stride_in_pixels'+CRLF+

            ')'+CRLF+
            '{'+CRLF+
            ' unsigned int n = get_global_id(0);'+CRLF+
            ' unsigned int srcx = n % src_stride_in_pixels[0];'+CRLF+
            ' unsigned int srcy = n / src_stride_in_pixels[0];'+CRLF+
            ' unsigned int dstx = n % dst_stride_in_pixels[0];'+CRLF+
            ' unsigned int dsty = n / dst_stride_in_pixels[0];'+CRLF+
            ' uchar4 color = src[(srcy*src_stride_in_pixels[0])+srcx];'+CRLF+
            ' float4 bigcolor = {0,0,0,0};//convert_float4(color); '+CRLF+
            ' int xx; '+CRLF+
            ' int yy; '+CRLF+
            ' int cnt = 0; '+CRLF+
            ' for (yy=0-'+inttostr(BLUR_RADIUS)+';yy<='+inttostr(BLUR_RADIUS)+';yy++) '+CRLF+
            ' { '+CRLF+
            '   int yyy = yy+dsty; '+CRLF+
            '   if ((yyy>=0) && (yyy<dst_height[0])) '+CRLF+
            '   { '+CRLF+
            '     for (xx=0-'+inttostr(BLUR_RADIUS)+';xx<='+inttostr(BLUR_RADIUS)+';xx++) '+CRLF+
            '     { '+CRLF+
            '       int xxx = xx+dstx; '+CRLF+
            '       if ((xxx>=0) && (xxx<src_width[0])) '+CRLF+
            '       { '+CRLF+
            '         uchar4 c = src[(yyy*src_stride_in_pixels[0])+xxx]; '+CRLF+
            '         float4 bc = convert_float4(c); '+CRLF+
            '         bigcolor += bc; '+CRLF+
            '         cnt++; '+CRLF+
            '       } '+CRLF+
            '     } '+CRLF+
            '   } '+CRLF+
            ' } '+CRLF+
            ' bigcolor /= cnt; '+CRLF+
            ' if (bigcolor.x > 255.0) bigcolor.x = 255.0;'+CRLF+
            ' if (bigcolor.y > 255.0) bigcolor.y = 255.0;'+CRLF+
            ' if (bigcolor.z > 255.0) bigcolor.z = 255.0;'+CRLF+
            ' if (bigcolor.w > 255.0) bigcolor.w = 255.0;'+CRLF+
            ' bigcolor.w = 0.0; '+CRLF+

            ' color = convert_uchar4(bigcolor); '+CRLF+
            ' dst[(dsty*dst_stride_in_pixels[0])+dstx] = color;//getBlurredSample(to_local(src), src_stride[0], dstx, dsty, 16, 16);'+CRLF+
            '}';
  end else begin
    opencl_code := '';
  end;

  //-------------------------------------------------------
  //This is the key function call.
  //dest.IterateExternalSource_begin returns a running TCommand descendent
  //if you want, you can just call TCommand.WaitFor to wait for it to finish
  //but in this particular case, we're going to have our form watch it in a Timer
  //so that we can progressively update the GUI to show the magic happening.
  self.activecmd := dest.IterateExternalSource_begin(src,
            opencl_code //OPTIONAL openCL variant
            ,
            //---------------------------------------------
            //This is the real work that our filter does in the CPU!!
            //THIS ONLY is used if the OpenCL version fails or is blank ''
            procedure (source: TFastBitmap; dest: TFastBitmap; region: TPixelRect; prog: PProgress)
                      //^read from this    //^write to this    //^don't write outside this
            var
              x,y: ni;
            begin
              //if a PProgress variable is passed, update it with our progress.
              if prog <> nil then prog.stepcount := region.bottom-region.Top;

              //for each line in the region
              for y := region.top to region.Bottom do begin
                //if a PProgress variable is passed, update it with our progress.
                if prog <> nil then prog.step := y-region.top;

                //for each pixel in the region
                for x := region.Left to region.right do begin
                  //output a blurred pixel, average from surrounding pixels
                  dest.Canvas.Pixels[x,y] := source.Canvas.getaveragepixel(x,y,BLUR_RADIUS,BLUR_RADIUS);
                end;
              end;
            end
            //---------------------------------------------
            ,
            TileNotify //optionally this gets called anytime a tile starts or completes work
  );



end;

procedure TForm1.btnCommandsClick(Sender: TObject);
var
  cmd: TCommand_IsPrime;
  ac: TAnonymousCommand<ni>;
  res: ni;
  tmStart,tmEnd: ticker;
begin
  //The following example tests for primes in the range of MIN_PRIME to MAX_PRIME
  //using TAnonymousCommand<> and TCommand_IsPrime
  //in a nutshell, what happens here is we create a command
  //for each prime number we want to test.  Upon calling Start()
  //TCommandProcessor will schedule the command to be executed when resources
  //are available.
  //This differs from the Queued sample internally.
  //TCommand is more expensive than TqueueItem, but is more flexible in the way
  //that resources are allocated.  Resources are allocated on-demand based
  //on the reported "expense" of the commands currently active.
  //By default, TCommand is set to CPUExpense := 1.0, meaning that 1 command will run on one Virtual Core
  //however, this is not the only resource control.  Setting CPUExpense to 0.5
  //will allow TCommandProcessor to run 2 commands per VirtualCore.
  //MemoryExpense := 1.0 tells the command processor that this command uses
  //   all available memory and should be run exclusively
  //There's also DiskExpense and NetworkExpense (similar)
  //MemoryExpenseGB := 1.0 tells the command processor that this command requires
  //   1 GB of memory and therefore the commandprocessor will run 1 command
  //   for each GB of memory available simultanously.
  //For more advanced patterns you can create completely custom resource
  //constraints.
  //  myCommand.Resources.SetResourceUsage('Whoziwhatzit', 0.3) tells the
  //  command processor that the command consumes 30% of total whoziwhatzit power.
  //  and commands will be allowed to run concurrently unless they would cause
  //  the total whoziwhatzit resource usage to exceed 1.0

  res := 0;

  RefreshProcInfo;

  tmStart := getticker;

  //Create an anonymous command that simply creates more commands
  //(bearing in mind that simply creating commands takes enough time that
  // you probably don't want to block the gui)
  ac := TAnonymousCommand<ni>.create(
          function: ni
          var
            x: ni;
            {$IFNDEF TI}
            cmd: Tcommand_IsPrime;
            {$ENDIF}
          begin
            res := 0;

            //this will show up in the thread debug window
            ac.Status := 'Creating Queue Items';
            ac.Step := 0;
            ac.StepCount := MAX_PRIME-MIN_PRIME;
            //-------------------------------------
            //for each prime we want to test
            for x := MIN_PRIME to MAX_PRIME do begin
              if (x and 1)=0 then continue;//skip evens
              ac.Step := x-MIN_PRIME;

              //create a command to test the prime
              cmd := TCommand_IsPrime.create;//SEE CODE FOR TCommand_IsPrime!!!!!!!! at the top of this file
              cmd.in_n := x;
              cmd.FireForget := true;//fire-forget means that it is auto-destroyed and we can't watch it
              cmd.start; //start the command (default command processor), you can pass a param to use an alternate command processor that you create.
              cmd.OnFinish_anon :=
              (
                                //This gets fired when the command completes,
                                //we will simply increment our tally if the
                                //command returns isPrime = true
                                procedure (cmd: TCommand)
                                begin
                                  if (cmd as TCommand_IsPrime).out_isPrime then
                                    inc(res);
                                end
              );

            end;

            //this is a hack.  We can't wait on BGCmd because it is the
            //commandprocessor for this anonymous command (it will never complete).
            //typically I would create another command processor and use it instead
            //but I'm feeling lazy.   Also not that WaitForall isn't a valid
            //solution if any commands are FireForget.
            while BGCmd.commandcount > 1 do
              sleep(1000);
//            BGCmd.WaitForAll(self);
          end
          ,
          procedure(result: ni)
          begin
            tmEnd := gettimesince(tmStart);
            lblResult2.caption := 'Found '+inttostr(res)+' primes in '+floatprecision(tmEnd/1000,3)+' seconds.';

          end,
          procedure(e: Exception)
          begin
            raise e;

          end
          , true, false
        );
  ac.SynchronizeFinish := true;
  ac.start;
  activecmd := ac;

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  frm: TFramTotalDebug;
begin
  frm := TframTotalDebug.create(self);
  frm.parent := panFrameHost;
  frm.Align := alClient;

end;

procedure TForm1.lblResultClick(Sender: TObject);
begin
  RefreshProcInfo;
end;

procedure TForm1.RefreshProcInfo;
begin
  lblResult.caption := GetEnabledCPUCount().tostring+' enabled cpus.'+CRLF+
                       Getnumberofphysicalprocessors().tostring+' physical cpus.'+CRLF+
                       Getnumberoflogicalprocessors().tostring+' logical cpus.'+CRLF;

  lblResult2.caption := GetEnabledCPUCount().tostring+' enabled cpus.'+CRLF+
                       Getnumberofphysicalprocessors().tostring+' physical cpus.'+CRLF+
                       Getnumberoflogicalprocessors().tostring+' logical cpus.'+CRLF;

end;

procedure TForm1.TabSheet1ContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin
  btnQueues.enabled := activecmd = nil;
end;

procedure TForm1.TileNotify(src, dest: TFastBitmap; region: TPixelRect;
  state: TTileState);
var
  tile: TFastBitmap;
  bm: TBitmap;
begin
  //
  if state = tsFinished then begin
    tile := TFastBitmap.create;
    tile.FromFAstBitmapRect(dest, region);
    bm := tile.tobitmap;
    image1.picture.Bitmap.Canvas.Draw(region.left, region.top, bm);

    bm.free;
    tile.free;
  end
  else if state = tsStarted then begin
    image1.Picture.bitmap.canvas.Pen.Color := clWhite;
    image1.Picture.bitmap.canvas.Pen.Mode := TPenMode.pmXor;
    region.Right := region.right;
    region.Bottom := region.bottom;
    image1.picture.bitmap.canvas.Rectangle(region.ToRect);
  end;

end;

procedure TForm1.tmCheckCommandTimer(Sender: TObject);
begin
  UpdateState;
  if activecmd <> nil then begin
//    if activecmd is Tcmd_FastBitmapIterate then begin
//      Tcmd_FastBitmapIterate(activecmd).dest.AssignToPicture(image1.picture);
//    end;

    if activecmd.IsComplete then begin
      activecmd.waitfor;

      if activecmd is Tcmd_FastBitmapIterate then begin
        lblResult2.Caption := 'Completed in '+floatprecision(gettimesince(tmstart)/1000,3)+' seconds.';
        Tcmd_FastBitmapIterate(activecmd).dest.AssignToPicture(image1.picture);
      end;

      activecmd.free;
      activecmd := nil;
    end;
  end;
end;

procedure TForm1.UpdateState;
begin
  Button1.Enabled := activecmd = nil;
  btnQueues.enabled := button1.enabled;
  btnCommands.enabled := button1.enabled;
end;

{ TQueueItem_IsPrime }

procedure TQueueItem_IsPrime.DoExecute;
begin
  inherited;
  out_IsPrime := CheckIsPrime(in_n, nil);
end;

{ Tcmd_CreatePrimeTestsUsingQueues }

function CheckIsPrime(n: int64; p: PProgress): boolean;
var
  x: ni;
  cx: ni;
begin
  result := true;
  cx := (n div 2);
  if assigned(p) then
    p.stepcount := cx;
  for x := 2 to cx do begin
    if (x and 1) = 0 then continue; //multiples of even numbers are also even, so skip anything without the low bit set
    //if no remainder from modulus operation
    if assigned(p) then
      p.step := x;
    if (n mod x) = 0 then begin

      //this is not prime
      result:= false;
      break;
    end;
  end;
end;


{ TCommand_IsPrime }

procedure TCommand_IsPrime.DoExecute;
begin
  inherited;
  //Easy as pie, a one-line command
  status := 'Checking prime '+inttostr(in_n);
  out_IsPrime := CheckIsPrime(in_n, @self.progress);
end;

end.
