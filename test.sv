interface inter_f (input bit clk, input bit rst);
  logic wr, done;
  logic [6:0] addr; 
  logic [7:0] din, datard;
endinterface

class transaction;
  rand bit [6:0] addr;
  rand bit [7:0] din;
  bit [7:0] datard; 
  bit wr;
  bit done; 

//   constraint address_range {addr inside {[0:31]};}; 
  
  function void display(string name);
    $display("---------------------------------");
    $display (" %s -- address=%b, data=%b",name, addr, din );
  endfunction
  
  
endclass

class generator;
  
  mailbox gen2driv;
  transaction trans;
  int  repeat_count;

  
  function new (mailbox gen2driv);
    this.gen2driv=gen2driv;
  endfunction
  
  task main();
    repeat (20) begin
      transaction trans;
      trans = new();
      trans.randomize();
      gen2driv.put(trans);
    end
  endtask
  
endclass

class driver;
  mailbox gen2driv; 
  transaction trans;
  virtual  inter_f int_v;
  event driv_done; 
  
  function new (virtual  inter_f int_v,mailbox gen2driv, event driv_done);
    this.gen2driv=gen2driv;
    this.int_v=int_v;
    this.driv_done = driv_done;
  endfunction
  
  
  task main();
forever      begin
      transaction trans;
        gen2driv.get(trans);
        @(posedge int_v.clk && int_v.done );
        int_v.addr <=trans.addr;
        int_v.din <=trans.din;
        int_v.done <=trans.done;
        int_v.datard <=trans.datard; 
        -> driv_done; 
      end
  endtask
endclass


class monitor;
  
  mailbox mon2scr;
  transaction trans;  
  virtual  inter_f int_v;
  event driv_done;
  
  function new (virtual  inter_f int_v,mailbox mon2scr, event driv_done);
    this.mon2scr=mon2scr;
    this.int_v=int_v;
    this.driv_done = driv_done;
   
  endfunction

  task main();
    transaction trans;
    forever begin
      @driv_done; 
      @(posedge int_v.clk);
        trans = new();
        trans.addr =int_v.addr;
        trans.din =int_v.din;
        trans.done =int_v.done;
        trans.datard =int_v.datard; 
        mon2scr.put(trans);
    end
  endtask
endclass

class scoreboard;
   
  mailbox mon2scb;
  virtual inter_f int_v;
  logic [7:0] mem [6:0]; 
  
  function new(mailbox mon2scb, virtual inter_f int_v );
    this.mon2scb = mon2scb;
    this.int_v = int_v; 
  endfunction
  
  
  task main (); 
    forever begin
        transaction trans; 
        trans = new ();
        mon2scb.get (trans); 
      $display (trans.done); 


      if (int_v.wr) begin
        mem [trans.addr] = trans.din; 
      end
      
      if (!int_v.wr) begin
        if (trans.done == 1) begin
          if (mem[trans.addr] == trans.datard) begin
            $display ("read test success"); 
          end
          else  $display ("not success"); 
        end 
      end
      
      
      
      	
      
  
    end
  endtask 
  
  

endclass



class environment;
  generator gen;
  driver driv;
  monitor mon;
  scoreboard scb;
  mailbox gen2driv;
  mailbox mon2scb;
  event driv_done;
 
virtual inter_f int_v;
  
  function new(virtual inter_f int_v);
    this.int_v=int_v;
    gen2driv=new();
    mon2scb=new ();
    gen=new (gen2driv);
    driv=new (int_v,gen2driv, driv_done);
    mon=new (int_v,mon2scb, driv_done);
    scb=new(mon2scb, int_v);
  endfunction
  
  task test();
    fork
      gen.main();
      driv.main();
      mon.main();
      scb.main();
    join
  endtask
  
  
  task run;

    test();
#200; 
 $finish;
  endtask
  
endclass

program test(inter_f i_intf);
  
  //declaring environment instance
  environment env;
  
  initial begin
    //creating environment
    env = new(i_intf);
    
    //setting the repeat count of generator as 4, means to generate 4 packets
    env.gen.repeat_count = 4;
    
    //calling run of env, it interns calls generator and driver main tasks.
    env.run();
  end
endprogram


module tb;
  
  bit clk, rst;
  inter_f int_f(clk, rst);
  test t(int_f);
  
  
  
  covergroup CG  @(posedge int_f.clk);
	option.per_instance = 1;    
  	option.comment = "CG";   
  	option.name = "CG";     
    
    operation : coverpoint int_f.wr {
      bins b0 = {1'b0}; 
      bins b1 = {1'b1}; 
    }
    
    
    }
    
    
endgroup

             CG cg_inst = new();

  i2c_mem i_square_c(
    .clk(int_f.clk),
    .wr(int_f.wr),
    .addr(int_f.addr),
    .din(int_f.din),
    .datard(int_f.datard),
    .rst(int_f.rst),
    .done(int_f.done)

    
  );
   always #2 clk=~ clk;
   initial begin 
    $dumpfile("dump.vcd"); 
     $dumpvars;
     clk=1;
     rst=1;
     #10;
     rst=0;

     int_f.wr= 1; 
     #1200
     
     int_f.wr= 0; 
     


     #3000;$finish;
  end
  

  
endmodule



