with Ada.Text_IO;                          use Ada.Text_IO;
with Ada.Real_Time;                        use Ada.Real_Time;
with Ada.Execution_Time;                   use Ada.Execution_Time;

with Audio.Wavefiles;                      use Audio.Wavefiles;
with Audio.Wavefiles.Data_Types;           use Audio.Wavefiles.Data_Types;
with Audio.Wavefiles.Generic_Fixed_Wav_IO;
with Audio.RIFF.Wav.Formats;               use Audio.RIFF.Wav.Formats;

with Time_Span_Conversions;
with Write_Random_Noise_Wavefile;

package body Wavefile_Benchmarking is

   Display_Debug_Info : constant Boolean := False;
   Verbose            : constant Boolean := True;

   WF_In   : Wavefile;
   WF_Out  : Wavefile;

   procedure Open_Wavefile;

   procedure Close_Wavefile;

   function kHz_Per_Sample
     (Elapsed_Time          : Time_Span;
      CPU_MHz               : Float;
      Number_Ch             : Positive;
      Number_Samples        : Long_Long_Integer) return Float;

   procedure Display_Info (Elapsed_Time          : Time_Span;
                           CPU_MHz               : Float;
                           Number_Ch             : Positive;
                           Number_Samples        : Long_Long_Integer;
                           Sample_Rate           : Positive);

   procedure Open_Wavefile is
      Wav_In_File_Name  : constant String := "2ch_long_noise.wav";
      Wav_Out_File_Name : constant String := "dummy.wav";

   begin
      Open (WF_In, In_File, Wav_In_File_Name);

      Set_Format_Of_Wavefile
        (WF_Out,
         Format_Of_Wavefile (WF_In));

      Open (WF_Out, Out_File, Wav_Out_File_Name);
   end Open_Wavefile;

   procedure Close_Wavefile is
   begin
      Close (WF_In);
      Close (WF_Out);
   end Close_Wavefile;

   function kHz_Per_Sample
     (Elapsed_Time          : Time_Span;
      CPU_MHz               : Float;
      Number_Ch             : Positive;
      Number_Samples        : Long_Long_Integer) return Float
   is
      Factor : constant Long_Long_Float := (Long_Long_Float (Number_Samples)
                                            * Long_Long_Float (Number_Ch));
   begin
      return Time_Span_Conversions.To_kHz (Elapsed_Time, CPU_MHz, Factor);
   end kHz_Per_Sample;

   procedure Display_Info (Elapsed_Time          : Time_Span;
                           CPU_MHz               : Float;
                           Number_Ch             : Positive;
                           Number_Samples        : Long_Long_Integer;
                           Sample_Rate           : Positive)
   is
      use Time_Span_Conversions;

      package F_IO is new Ada.Text_IO.Float_IO (Float);

      --  Duration_In_Seconds : Long_Long_Float :=
      --                          Long_Long_Float (Number_Samples)
      --                          / Long_Long_Float (Sample_Rate);

      Factor : constant Long_Long_Float := (Long_Long_Float (Number_Samples)
                                            * Long_Long_Float (Number_Ch));
   begin
      Put ("CPU time: ");
      F_IO.Put (Item => To_Miliseconds (Elapsed_Time),
                Fore => 5, Aft => 4, Exp => 0);
      Put (" miliseconds");
      Put (" for " & Long_Long_Integer'Image (Number_Samples) & " samples");
      Put (" on " &
             Integer'Image (Number_Ch) & " channels");
      Put (" at " &
             Integer'Image (Sample_Rate) & " Hz");
      New_Line;

      Put ("Overall Perf.: ");
      F_IO.Put (Item => (To_MHz (Elapsed_Time, CPU_MHz, Factor)
                         * Float (Sample_Rate)),
                Fore => 5, Aft => 4, Exp => 0);
      Put (" MHz (per channel @ " & Positive'Image (Sample_Rate) & " kHz)");
      New_Line;

      Put ("Overall Perf.: ");
      F_IO.Put (Item => To_kHz (Elapsed_Time, CPU_MHz, Factor),
                Fore => 5, Aft => 4, Exp => 0);
      Put (" kHz (per channel and per sample)");
      New_Line;
   end Display_Info;

   function Benchm_CPU_Time (CPU_MHz : Float) return Wavefile_Benchmark_kHz
   is
      Res                   : Wavefile_Benchmark_kHz;

      Start_Time, Stop_Time : CPU_Time;
      Elapsed_Time          : Time_Span;

      Sample_Rate           : Positive;

      package Wav_IO is new Audio.Wavefiles.Generic_Fixed_Wav_IO
        (Wav_Sample    => Wav_Fixed_16,
         Wav_MC_Sample => Wav_Buffer_Fixed_16);
      use Wav_IO;

      Cnt, Total_Cnt : Long_Long_Integer := 0;

   begin
      Write_Random_Noise_Wavefile;

      Open_Wavefile;

      Sample_Rate := To_Positive
        (Format_Of_Wavefile (WF_In).Samples_Per_Sec);

      pragma Assert
        (Format_Of_Wavefile (WF_In).Bits_Per_Sample = Bit_Depth_16
         and not Is_Float_Format (Format_Of_Wavefile (WF_In)));

      if Display_Debug_Info then
         Put_Line ("========================================================");
         Put_Line ("= Read");
         Put_Line ("========================================================");
      end if;

      Start_Time := Clock;

      loop
         Read_Wav_MC_Samples : declare
            Dummy_Wav_Buf : constant Wav_Buffer_Fixed_16 := Get (WF_In);
         begin
            Cnt := Cnt + 1;
            exit when Is_EOF (WF_In);
         end Read_Wav_MC_Samples;
      end loop;

      Stop_Time    := Clock;
      Elapsed_Time := Stop_Time - Start_Time;

      --  Res (Wavefile_Read_Benchmark) := Elapsed_Time;
      Res (Wavefile_Read_Benchmark) :=
        kHz_Per_Sample (Elapsed_Time,
                        CPU_MHz,
                        Number_Of_Channels (WF_In),
                        Cnt);

      if Display_Debug_Info then
         Display_Info (Elapsed_Time,
                       CPU_MHz,
                       Number_Of_Channels (WF_In),
                       Cnt,
                       Sample_Rate);

         Put_Line ("========================================================");
         Put_Line ("= Write");
         Put_Line ("========================================================");
      end if;

      Total_Cnt := Cnt;
      Cnt       := 0;

      declare
         Wav_Buf                           : constant Wav_Buffer_Fixed_16
           (1 .. Number_Of_Channels (WF_In)) := (others => 0.5);
      begin
         Start_Time := Clock;

         loop
            Write_Wav_MC_Samples : declare
            begin
               Cnt := Cnt + 1;
               Put (WF_Out, Wav_Buf);
               exit when Cnt = Total_Cnt;

            end Write_Wav_MC_Samples;
         end loop;

         Stop_Time    := Clock;
         Elapsed_Time := Stop_Time - Start_Time;

         --  Res (Wavefile_Write_Benchmark) := Elapsed_Time;
         Res (Wavefile_Write_Benchmark) :=
           kHz_Per_Sample (Elapsed_Time,
                           CPU_MHz,
                           Number_Of_Channels (WF_In),
                           Cnt);
      end;

      if Display_Debug_Info then
         Display_Info (Elapsed_Time,
                       CPU_MHz,
                       Number_Of_Channels (WF_In),
                       Cnt,
                       Sample_Rate);
      end if;

      Close_Wavefile;

      return Res;
   end Benchm_CPU_Time;

   procedure Benchm_CPU_Time (CPU_MHz :     Float;
                              Results : out Wavefile_Benchmark_Infos) is
   begin
      for I in Results'Range loop
         if Verbose and not Display_Debug_Info then
            Put (".");
         end if;
         Results (I) := Benchm_CPU_Time (CPU_MHz);
      end loop;
      if Verbose and not Display_Debug_Info then
         New_Line;
      end if;
   end Benchm_CPU_Time;

end Wavefile_Benchmarking;
