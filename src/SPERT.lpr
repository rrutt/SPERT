Program SPERT;
{ Copyright © 2024 Rick Rutt }

{ Stochastic
  Project
  Evaluation and
  Review
  Technique }

{ Based on classical Three-Estimate P.E.R.T. }

{ ***
  This source file can be compiled under Free Pascal
  using the Lazarus integrated development environment.
  *** }

{$WARN 6018 off : unreachable code}
{$WARN 4044 off : Comparison might be always false due to range of constant and expression}

Uses sysutils;

Const
  VERSION = '1.0.2+20240525';

  SHORT_STR_LEN = 10;
  LONG_STR_LEN = 255;
  MAX_FINISH = 400; { Largest # work days for a project }
  TRUNCATE_UP = 0.99;
  EPSILON = 1e-5;
  //HIGH_INTEGER = 32767;
  INFINITY = 1e37;
  BLANK = ' ';
  BLOB = 'X';
  SUCCESSOR_CHAR = '^';
  MILESTONE_CHAR = '#';
  PRIORITY_CHAR = '!';
  RESOURCE_CHAR = '@';
  DITTO_CHAR = '"';

  DaysInMonth: array [1..12] Of integer = (31, 28, 31, 30, 31, 30,
                                           31, 31, 30, 31, 30, 31);

Type
  ShortString = string [SHORT_STR_LEN];
  LongString = string [LONG_STR_LEN];

  ShortStrLen = 0..SHORT_STR_LEN;
  LongStrLen = 0..LONG_STR_LEN;
  FinishIndex = 0..MAX_FINISH;

  WhichPass = (FORWARD_PASS, BACKWARD_PASS);

  TaskPtr = ^TaskRec;
  PredSuccPtr = ^PredSuccRec;
  MilestonePtr = ^MilestoneRec;

  TaskRec = Record
    TaskCode: ShortString;
    TaskDesc: LongString;
    TaskNbr: integer;
    TaskResourceCount: single;
    Priority: single;
    HighPriority: boolean;
    Milestone: MilestonePtr;

    DurOptimistic, DurLikely, DurPessimistic: single;
    MeanDur, CalculatedMean, SimulatedDur: single;
    MeanFinish, MeanFloat, MeanDelay, Criticality: single;

    TimeA, TimeB: array [WhichPass] Of single;
    FirstPred, FirstSucc: PredSuccPtr;

    NbrSucc, NbrPred: integer;

{============================================Page 3==================================================}
{ "Constant" # of succ/pred }
    PrecedenceCount: integer;
{ Counts down during each calculation }
    NextTask, NextInQueue: TaskPtr;
    WasQueued: boolean;
  End;

  PredSuccRec = Record
    PredSuccTask: TaskPtr;
    NextPredSucc: PredSuccPtr;
  End;

  MilestoneRec = Record
    FinishDistribution: array [FinishIndex] Of integer;
    MinFinIdx, MaxFinIdx: FinishIndex;
  End;

Var
  TaskCount: integer;
  FinIdx, MinResourceFinIdx, MaxResourceFinIdx: FinishIndex;
  FileName: LongString;
  InputFile: text;
  InputLine: LongString;

  NetworkDescription: LongString;

  PrintNetwork, PrintDetails, PrintGantt, PrintResources,
  PrintFinish, PrintPrn: boolean;
  Simulation, NbrSimulations, ResourceLimit: integer;
  NetworkFinish, MeanNetworkFinish: single;

  ResourceUse, MeanResourceUse, MaxResourceUse: array [FinishIndex] Of single;
  HighResourceUse, LowResourceUse: single;

  MaxResourceCount: integer; { Used in printing interface file }

  Task, FirstTask, LastTask, PrevTask, PrevPred, PrevSucc, Queue: TaskPtr;
  PredSucc: PredSuccPtr;

  StartDate: integer;

  PrnFile: Text;

Procedure TypeHelpMsg;
Begin
  writeln;
  writeln (' Command line arguments allowed are:');
  writeln;
  writeln (' filename  input file name');
  writeln (' /PN       Print input Network');
  writeln (' /PD       Print Detailed analysis results by task');
{============================================Page 4==================================================}
  writeln (' /PG       Print Gantt chart');
  writeln (' /PR       Print Resource usage histogram and total');
  writeln (' /PF       Print distributions of milestone Finish times');
  (*
  writeln (' /PI       Print an Interface file (for Open Workbench) in SPERT.PRN');
          { https://en.wikipedia.org/wiki/Open_Workbench }
          { https://sourceforge.net/projects/openworkbench/ }
  *)
  writeln (' /NSn      Number of Simulations is "n" (default is l)');
  writeln (' /RLn      Resource Limit is "n" (default is infinity)');
  writeln (' /SDmmdd   Start Date month and day (for time scale headings)');
  writeln ('           (Leading zeros are required for "mm" and "dd")');
  writeln;
  writeln (' The standard output may be redirected with >FILENAME');
  writeln;
  writeln (' The input file is read in the following format (any blank lines are ignored):');
  writeln;
  writeln (' Project Name on one line');
  writeln (' TaskCode Optimistic MostLikely Pessimistic [@ResCount] [Task Desc]');
  writeln (' ...');
  writeln (' *');
  writeln (' PredTaskCode SuccTaskCode');
  writeln (' ...');
  writeln (' *');
  writeln;
  writeln (' "TaskCode" is a short taskname (up to ',
           SHORT_STR_LEN:2, ' chars.) without blanks.');
  writeln (' If "TaskCode" begins with a #, then it is a Milestone task.');
  writeln (' Preceding "TaskCode" or "#TaskCode" with ^ implies that this');
  writeln (' task is a successor to the task above it.');
  writeln (' If "TaskCode" ends with a !, the task is a High Priority Task.');
  writeln;
  writeln (' "Optimistic", "MostLikely", and "Pessimistic" are task time span estimates.');
  writeln;
  writeln (' "ResCount" is an optional real Resource count. (1.0 is assumed if omitted).');
  writeln;
  writeln (' "Task Desc" is an optional longer description and allows blanks.' );
  writeln;
  writeln (' "PredTaskCode" and "SuccTaskCode" form a precedence pair of two tasks.');
  writeln (' (The # for Milestones and ! for Priority Tasks are optional');
  writeln (' for these task codes.)');
  writeln (' A ditto (") for either "PredTaskCode" or "SuccTaskCode"');
  writeln (' indicates reuse of the value from the preceding line.');
{============================================Page 5==================================================}
  writeln;
  writeln (' (The last * line is optional.)');
  writeln;
  writeln (' In the output Gantt chart, the following symbols are used:');
  writeln;
  writeln (' X = One day in task on the Critical Path');
  writeln (' 9 = One day in task that was critical in 90% of simulations');
  writeln (' ...');
  writeln (' 1 = One day in task that was critical in 10% of simulations');
  writeln (' + = One day in non-critical task');
  writeln (' - = trailing float (resource limits ignored)');
  writeln (' . = leading delay (only occurs if resources are limited)');
  writeln;
  writeln (' In the resource usage chart, the following symbols are used:');
  writeln;
  writeln (' X = One unit of resource fully used that day');
  writeln (' 9 = 0.9 units of resource');
  writeln (' ...');
  writeln (' 1 = 0.1 units of resource');
  writeln;
  writeln (' In the finish distributions, an asterisk marks the "mean" value.');
  writeln;
End; { TypeHelpMsg }

Function UpperStr (s: ShortString): ShortString;
Var i: integer;
Begin
  For i := 1 To Length (s) Do
    s [i] := UpCase (s [i]);
  UpperStr := s;
End;

Function CopyLength (Line: LongString; NewLength: LongStrLen): LongString;
Var
  s: Longstring;
Begin
  If (NewLength = 0) Then s := ''
  Else If (Length (Line) > NewLength) Then s := Copy (Line, 1, NewLength)
  Else
    Begin
      s := line;
      While (Length (s) < NewLength) Do
        s := Concat (s, BLANK);
    End; { else too short }
  CopyLength := s;
End; { CopyLength }

{============================================Page 6==================================================}
Procedure ChopOff (Var Line: LongString; Var Front: ShortString);
Var p: integer;
Begin
  If (Line = BLANK) Then Front := BLANK
  Else
    Begin
      p := Pos (BLANK, Line);
      If (p = 0) Then
        Begin
          Front := line;
          Line := BLANK;
        End
      Else If (p > succ (SHORT_STR_LEN)) Then
             Begin
               Front := Copy (Line, 1, SHORT_STR_LEN);
               Line := TrimLeft (Copy (Line, succ (p), LONG_STR_LEN));
               writeln (StdErr, '*** Token truncated to "', Front, '"');
               writeln (StdErr, InputLine);
             End
      Else
        Begin
          Front := Copy (Line, 1, pred (p));
          Line := TrimLeft (Copy (Line, succ (p), LONG_STR_LEN));
        End;
    End; { else not blank input }
End; { ChopOff }

Procedure Initialize;
Var p, value, valcode: integer;
  pstr: LongString;
  arg: ShortString;
Begin
  FileName := 'SPERT.DAT';
  FirstTask := Nil;
  LastTask := Nil;
  PrevTask := Nil;
  PrevPred := Nil;
  PrevSucc := Nil;

  PrintNetwork := FALSE;
  PrintDetails := FALSE;
  PrintGantt := FALSE;
  PrintResources := FALSE;
  PrintFinish := FALSE;
  PrintPrn := FALSE;
  NbrSimulations := 1;
  ResourceLimit := 0; { treated as infinity }

  HighResourceUse := 0.0;
  LowResourceUse := INFINITY;
  MaxResourceCount := 0;

  StartDate := 0;

  Randomize;

{============================================Page 7==================================================}
  p := 0;
  While (p < ParamCount) Do
    Begin
      p := Succ (p);
      pstr := ParamStr (p);
      If (pstr [1] = '/') Then
        Begin
          arg := UpperStr (Copy (pstr, 1, 3));
          If (Length (pstr) < 4) Then
            Begin
              value := 0;
              valcode := 0;
            End
          Else Val (Copy (pstr, 4, SHORT_STR_LEN), value, valcode);

          If (arg = '/PN') Then PrintNetwork := TRUE
          Else If (arg = '/PD') Then PrintDetails := TRUE
          Else If (arg = '/PG') Then PrintGantt := TRUE
          Else If (arg = '/PR') Then PrintResources := TRUE
          Else If (arg = '/PF') Then PrintFinish := TRUE
          (*
          Else If (arg = '/PI') Then PrintPrn := TRUE
          *)
          Else If (arg = '/NS') Then
                 Begin
                   If ((valcode > 0) Or (value < 1)) Then writeln (StdErr,
                                                       '*** Not a valid number in SPERT argument: "'
                                                                   , pstr, '"')
                   Else NbrSimulations := value;
                 End { else if /NS }
          Else If (arg = '/RL') Then
                 Begin
                   If ((valcode > 0) Or (value < 0)) Then writeln (StdErr,
                                                       '*** Not a valid number in SPERT argument: "'
                                                                   , pstr, '"')
                   Else
                     Begin
                       ResourceLimit := value;
                     End;
                 End { else if /RL }
          Else If (arg = '/SD') Then
                 Begin
                   If ((valcode > 0) Or (value < 0)) Then writeln (StdErr,
                                                       '*** Not a valid number in SPERT argument: "'
                                                                   , pstr, '"')
                   Else
                     Begin
                       StartDate := value;
                     End;
                 End { else if /SD }
          Else writeln (StdErr, '*** Unknown argument in SPERT: "', pstr, '"');
        End { if slash argument }
      Else FileName := pstr;
    End; { while }
End; { Initialize }

Procedure NewPrecedence (p, s: TaskPtr);
Begin
  New (PredSucc); { handle successor }
  PredSucc^.PredSuccTask := s;
  PredSucc^.NextPredSucc := p^.FirstSucc;
  p^.FirstSucc := Predsucc;
  p^.NbrSucc := Succ (p^.NbrSucc);

  New (PredSucc); { handle predecessor }
  PredSucc^.PredSuccTask := p;
  PredSucc^.NextPredSucc := s^.FirstPred;
  s^.FirstPred := PredSucc;

{============================================Page 8==================================================}
  s^.NbrPred := Succ (s^.NbrPred);
End; { NewPrecedence }

Procedure ProcessTask;
Var tcode, vstring: ShortString;
  tline: LongString;
  v1, v2, v3: single;
  c1, c2, c3: integer;
  trc: single;
  cr: integer;
  autoprec: boolean;
Begin
  vstring := '';
  tcode := '';
  tline := TrimLeft (InputLine);
  ChopOff (tline, tcode);
  ChopOff (tline, vstring);
  Val (vstring, v1, c1);
  ChopOff (tline, vstring);
  Val (vstring, v2, c2);
  Chopoff (tline, vstring);
  Val (vstring, v3, c3);

  If (tline [1] = RESOURCE_CHAR) Then
    Begin
      Chopoff (tline, vstring);
      vstring [1] := '0'; { replace @ sign with zero digit }
      Val (vstring, trc, cr)
    End
  Else
    Begin { assume one resource }
      trc := 1.0;
      cr := 0;
    End;

  If ((tcode = BLANK) Or (c1 > 0) Or (c2 > 0) Or (c3 > 0)) Then
    Begin
      writeln (StdErr, '*** Error in Task Input Line:');
      writeln (StdErr, InputLine);
    End
  Else
    Begin
      New (Task);

      autoprec := FALSE;
      If (tcode [1] = SUCCESSOR_CHAR) Then
        Begin { Implied precedence }
          tcode := Copy (tcode, 2, SHORT_STR_LEN); { Remove leading char, }
          If (PrevTask = Nil) Then
            Begin
              writeln (StdErr, '*** No preceding Task in Input Line:');
              writeln (StdErr, InputLine);
            End
          Else
            Begin
              autoprec := TRUE;
            End; { else precedence o.k. }
        End; { if implied precedence }

      With Task^ Do
        Begin
          TaskCode := tcode;
          TaskDesc := tline;
          TaskNbr := TaskCount;
          HighPriority := (tcode [Length (tcode)] = PRIORITY_CHAR);
          DurOptimistic := v1;
          DurLikely := v2;
          DurPessimistic := v3;
          If ((cr > 0) Or (trc < 0.0)) Then
            Begin
              writeln (StdErr, '*** Bad Resource Count (1.0 assumed):');
              writeln (StdErr, InputLine);
              TaskResourceCount := 1.0;
            End
          Else If ((ResourceLimit > 0) And (trc > ResourceLimit)) Then
                 Begin
                   writeln (StdErr, '*** Resource Count too big (',
{============================================Page 9==================================================}
                            ResourceLimit, ' assumed):');
                   writeln (StdErr, InputLine);
                   TaskResourceCount := ResourceLimit;
                 End
          Else
            Begin
              TaskResourceCount := trc;
            End;

          If (trunc (TaskResourceCount) > MaxResourceCount) Then
            Begin
              MaxResourceCount := trunc (TaskResourceCount);
            End;

          MeanDur := 0;
          CalculatedMean := 0;
          SimulatedDur := 0;
          MeanFinish := 0;
          MeanFloat := 0;
          MeanDelay := 0;
          Criticality := 0;
          NbrSucc := 0;
          NbrPred := 0;
          FirstPred := Nil;
          FirstSucc := Nil;
          NextTask := Nil;
          NextInQueue := Nil;

          Milestone := Nil;
          If ((PrintFinish) And (TaskCode [1] = MILESTONE_CHAR)) Then
            Begin
              New (Milestone);
              For FinIdx := 0 To MAX_FINISH Do
                Begin
                  Milestone^.FinishDistribution [FinIdx] := 0;
                End;
              Milestone^.MinFinIdx := MAX_FINISH;
              Milestone^.MaxFinIdx := 0;
            End; { if milestone task }
        End; { with Task^ }

      If (autoprec) Then NewPrecedence (PrevTask, Task);
      PrevTask := Task;

      If (FirstTask = Nil) Then
        Begin
          FirstTask := Task;
          LastTask := Task;
        End
      Else If (LastTask <> Nil) Then
             Begin
               LastTask^.NextTask := Task;
               LastTask := Task;
             End;
    End; { else input line ok }
End; { ProcessTask }

Function FindTask (t: ShortString): TaskPtr;
Var curtask: TaskPtr;
  s: ShortString;
  found: boolean;
  ls: ShortStrLen;
Begin
  curtask := FirstTask;
  found := FALSE;
  While ((Not found) And (curtask <> Nil)) Do
    Begin
      s := curtask^.TaskCode;
      found := (t = s);
      If (Not found) Then If (s [1] = MILESTONE_CHAR) Then
                            Begin
                              found := (t = Copy (s, 2, SHORT_STR_LEN));
                            End;
      If (Not found) Then
        Begin
{============================================Page 10==================================================}
          ls := length (s);
          If ((ls > 1) And (s [ls] = PRIORITY_CHAR)) Then
            Begin
              found := (t = Copy (s, 1, (ls - 1)));
              If (Not found) Then If (s [1] = MILESTONE_CHAR) Then
                                    Begin
                                      found := (t = Copy (s, 2, (ls - 2)));
                                    End;
            End;
        End;
      If (Not found) Then curtask := curtask^.NextTask;
    End; { while }
  FindTask := curtask;
End; { FindTask }

Procedure ProcessPrecedence;
Var pstr, sstr: ShortString;
  p, s: TaskPtr;
  tline: Longstring;
Begin
  sstr := '';
  pstr := '';
  tline := TrimLeft (InputLine);
  ChopOff (tline, pstr);
  ChopOff (tline, sstr);

  If (pstr = DITTO_CHAR) Then
    Begin
      p := PrevPred;
    End
  Else
    Begin
      p := FindTask (pstr);
    End;

  If (sstr = DITTO_CHAR) Then
    Begin
      s := PrevSucc;
    End
  Else
    Begin
      s := FindTask (sstr);
    End;

  If ((P = Nil) Or (s = Nil)) Then
    Begin
      writeln (StdErr, '*** Unknown Task in Precedence Input Line:');
      writeln (StdErr, InputLine);
    End
  Else If (p = s) Then
         Begin
           writeln (StdErr, '*** Identical Tasks in Precedence Input Line:');
           writeln (StdErr, InputLine);
         End
  Else
    Begin
      NewPrecedence (p, s);
      PrevPred := p;
      PrevSucc := s;
    End; { input line ok }
End; { ProcessPrecedence }

Procedure ProcessInput;
Var processing: (TASKS, PRECEDENCES);
Begin
  assign (InputFile, FileName);

  reset (InputFile);
  If (EOF (InputFile)) Then
    Begin
      writeln (StdErr, '*** Input File "', FileName, '" is empty');
      flush (StdErr);
{============================================Page 11==================================================}
      halt;
    End;

  Repeat
    readln (InputFile, NetworkDescription);
    NetworkDescription := TrimRight (NetworkDescription);
  Until (NetworkDescription <> '');

  writeln (StdErr);
  writeln (StdErr, 'Processing ', NetworkDescription);
  writeln (StdErr, ' from file ', FileName);

  processing := TASKS;
  TaskCount := 0;
  While (Not EOF (InputFile)) Do
    Begin
      readln (InputFile, InputLine);
      InputLine := TrimRight (InputLine);
      If (InputLine <> '') Then Case processing Of
                                     TASKS:
                                            Begin
                                              If (InputLine = '*') Then processing := PRECEDENCES
                                              Else ProcessTask;
                                            End; { case TASKS }
                                     PRECEDENCES:
                                                  Begin
                                                    If (InputLine <> '*') Then ProcessPrecedence;
                                                  End; { case PRECEDENCES }
        End; { case }
      TaskCount := succ (TaskCount);
    End; { while not end of file }
  Close (InputFile);

  TaskCount := succ (TaskCount);
End; { Process Input }

Procedure ShowNetwork;
Var t: TaskPtr;
  ps: PredSuccPtr;
Begin
  writeln (StdErr);
  writeln (StdErr, '(Printing Network)');

  writeln;
  writeln;
  writeln (NetworkDescription);
  writeln;
  writeln ('Listing of Network:');
  writeln;

  t := FirstTask;
  While (t <> Nil) Do
    Begin
      writeln (CopyLength (t^.TaskCode, SHORT_STR_LEN),
      BLANK, t^.DurOptimistic: 5: 1,
                                  BLANK, t^.DurLikely: 5: 1,
                                                          BLANK, t^.DurPessimistic: 5: 1,
                                                                                       BLANK, t^.
                                                                                       TaskDesc);

      If (t^.TaskResourceCount <> 1.0) Then
        Begin
          writeln (' ', RESOURCE_CHAR, t^.TaskResourceCount:4:1);
        End;

      ps := t^.FirstPred;
      While (ps <> Nil) Do
        Begin
          writeln (' <-- ', ps^.PredSuccTask^.TaskCode);
          ps := ps^.NextPredSucc;
        End; { while processing predecessors }
      t := t^.NextTask;
    End; { while processing tasks }

{============================================Page 12==================================================}
End; { ShowNetwork }

Procedure ClearMeanValues;
Begin
  Task := FirstTask;
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          MeanDur := 0.0;
          MeanFinish := 0.0;
          MeanFloat := 0.0;
          MeanDelay := 0.0;
          Criticality := 0.0;
        End; { with Task }

      Task := Task^.NextTask;
    End; { while Task }

  If ((PrintResources) Or (ResourceLimit > 0)) Then
    Begin
      MaxResourceFinIdx := 0; { Initialize "on the fly" clearing of values }
      ResourceUse [MaxResourceFinIdx] := 0.0;
      MeanResourceUse [MaxResourceFinIdx] := 0.0;
      MaxResourceUse [MaxResourceFinIdx] := 0.0;
    End;

  MeanNetworkFinish := 0.0;
End; { ClearMeanValues }

Procedure AddToQueue (ptr: TaskPtr);
Var prev, cur: TaskPtr;
  found: boolean;
Begin
  If (ResourceLimit = 0) Then
    Begin
      { order does not matter if resources are unlimited }
      ptr^.NextInQueue := Queue;
      Queue := ptr;
    End

  Else
    Begin { preserve priority order }
      If (ptr^.HighPriority) Then
        Begin
          ptr^.Priority := ptr^.TaskNbr - TaskCount;
        End { if high priority task, ignore early start time }
      Else
        Begin
          ptr^.Priority :=
                           (TaskCount * trunc (ptr^.TimeA [FORWARD_PASS] + EPSILON)) +
                           ptr^.TaskNbr;
        End; { else normal priority task }
      prev := Nil;
      cur := Queue;
      found := (cur = Nil);
      While (Not found) Do
        Begin
          If (ptr^.Priority < cur^.Priority) Then found := TRUE
          Else
            Begin
              prev := cur;
              cur := cur^.NextInQueue;
              found := (cur = Nil);
            End;
        End; { while finding spot in queue }

      If (prev = Nil) Then Queue := ptr { insert at head of queue }
      Else prev^.NextInQueue := ptr; { insert in middle of queue }
      ptr^.NextInQueue := cur;
    End; { else preserving priority }

  ptr^.WasQueued := TRUE;
End; { AddToQueue }

{============================================Page 13==================================================}
Function InitialResourceDelay (ta, trc: single): single;
Var i: FinishIndex;
  start, use, nextuse, avail, reslimit, uselimit: single;
Begin
  If (trc = 0.0) Then
    Begin { no resources used, so no delay }
      InitialResourceDelay := 0.0;
    End
  Else
    Begin
      reslimit := ResourceLimit - EPSILON;
      uselimit := ResourceLimit - trc;

      i := trunc (ta + EPSILON);
      If (i < MinResourceFinIdx) Then i := MinResourceFinIdx;

      If (i > MaxResourceFinIdx) Then use := 0
      Else use := ResourceUse [i];

      While (use > reslimit) Do
        Begin { skip past any resource overuse }
          i := succ (i);
          MinResourceFinIdx := i;

          If (i > MaxResourceFinIdx) Then use := 0
          Else use := ResourceUse [i];

        End; { while }

      If (i >= MaxResourceFinIdx) Then nextuse := 0
      Else nextuse := ResourceUse [succ (i)];

      While (nextuse > uselimit) Do
        Begin
          { make sure we have enough resources in next time period }
          i := succ (i);

          If (i > MaxResourceFinIdx) Then use := 0
          Else use := ResourceUse [i];

          If (i >= MaxResourceFinIdx) Then nextuse := 0
          Else nextuse := ResourceUse [succ (i)];

        End; { while }

      avail := ResourceLimit - use;

      start := i;
      If (avail < trc) Then start := start + ((trc - avail) / trc); { delay within time unit }
      If (start < ta) Then start := ta; { correct for original truncation }

      InitialResourceDelay := (start - ta) + EPSILON;
    End; { else trc > 0.0 }
End; { InitialResourceDelay }

Function ResourceDelay (ta, trc, tdur: single): single;
Var begidx, endidx, lateidx, i: FinishIndex;
  delay, beg, uselimit: single;
Begin
  If (trc = 0.0) Then
    Begin { no resources used, so no delay }
      ResourceDelay := 0.0;
    End
  Else
    Begin
      delay := InitialResourceDelay (ta, trc);

      beg := ta + delay;
      begidx := trunc (beg + EPSILON);
      endidx := trunc (beg + tdur + (1.0 - EPSILON));

{============================================Page 14==================================================}
      If (begidx < endidx) Then
        Begin
          If (endidx > MaxResourceFinIdx) Then endidx := MaxResourceFinIdx;

          lateidx := begidx;
          uselimit := ResourceLimit - trc;

          i := succ (begidx);
          While (i <= endidx) Do
            Begin
              If (ResourceUse [i] > uselimit) Then lateidx := i;
              i := succ (i);
            End; { while searching time periods for resource overloads }

          If (lateidx > begidx) Then
            Begin
              beg := lateidx;
              delay := (beg - ta) +
                       ResourceDelay (beg, trc, tdur); { recursive call }
            End; { if found following resource overload }

        End; { if more than one time unit }

      ResourceDelay := delay;
    End; { else trc > 0.0 }
End; { ResourceDelay }

Procedure AccumulateResources (ta, tb, trc: single);
Var begidx, endidx, i: FinishIndex;
  use: single;
Begin
  begidx := trunc (ta + EPSILON);
  endidx := trunc (tb + EPSILON);

  If (endidx > MaxResourceFinIdx) Then
    Begin
      For i := (succ (MaxResourceFinIdx)) To endidx Do
        Begin
          ResourceUse [i] := 0.0;
          MeanResourceUse [i] := 0.0;
          MaxResourceUse [i] := 0.0;
        End; { for i }
      MaxResourceFinIdx := endidx;
    End; { if "on the fly" clearing of values }

  If (begidx = endidx) Then
    Begin
      use := ResourceUse [endidx] + ((tb - ta) * trc);
      ResourceUse [endidx] := use;
    End { if within one time unit }
  Else
    Begin
      i := succ (begidx);
      use := ResourceUse [begidx] + ((i - ta) * trc);
      ResourceUse [begidx] := use;

      If (ResourceLimit > 0) Then
        Begin
          If (use > (ResourceLimit - EPSILON)) Then MinResourceFinIdx := succ (begidx)
        End; { if limiting resources }

      While (i < endidx) Do
        Begin
          use := ResourceUse [i] + trc;
          ResourceUse [i] := use;

          If (ResourceLimit > 0) Then
            Begin
              If (use > (ResourceLimit - EPSILON)) Then MinResourceFinIdx := succ (i)
            End; { if limiting resources }

          i := succ (i);
        End; { for full-use time units, if any )}

{============================================Page 15==================================================}
      use := ResourceUse [endidx] + ((tb - endidx) * trc);
      ResourceUse [endidx] := use;
    End; { else more than one time unit }

  If (ResourceLimit > 0) Then
    Begin
      If (use > (ResourceLimit - EPSILON)) Then MinResourceFinIdx := succ (endidx)
    End; { if limiting resources }

End; { AccumulateResources }

Procedure ScheduleNetwork (Pass: WhichPass);
Var p: PredSuccPtr;
  t: TaskPtr;
  ta, tb, delay, trc, tdur: single;
Begin
  Queue := Nil; { Initialize Queue to Tasks with no precedences }
  Task := FirstTask;
  While (Task <> Nil) Do
    Begin
      With Task^ Do
        Begin
          TimeA [Pass] := 0.0;
          TimeB [Pass] := 0.0;

          If (Pass = FORWARD_PASS) Then PrecedenceCount := NbrPred
          Else PrecedenceCount := NbrSucc;
          If (PrecedenceCount = 0) Then AddTOQueue (Task);

        End; { with Task }

      Task := Task^.NextTask;
    End; { while Task }

  While (Queue <> Nil) Do
    Begin
      ta := Queue^.TimeA [Pass];
      trc := Queue^.TaskResourceCount;
      tdur := Queue^.SimulatedDur;

      If ((Pass = FORWARD_PASS) And (ResourceLimit > 0)) Then
        Begin
          delay := ResourceDelay (ta, trc, tdur);
          ta := ta + delay;
          Queue^.MeanDelay := Queue^.MeanDelay + delay;
        End; { if checking resource availability }

      tb := ta + tdur;
      Queue^.TimeB [Pass] := tb;

      If (Pass = FORWARD_PASS) Then
        Begin
          If ((PrintResources) Or (ResourceLimit > 0)) Then AccumulateResources (
                                                                                 ta, tb, trc);
          If (tb > NetworkFinish) Then NetworkFinish := tb;
          p := Queue^.FirstSucc;
        End
      Else p := Queue^.FirstPred;

      Queue := Queue^.NextInQueue;

      While (p <> Nil) Do
        Begin
          t := p^.PredSuccTask;

          If (tb > t^.TimeA [Pass]) Then t^.TimeA [Pass] := tb;
          t^.PrecedenceCount := pred (t^.PrecedenceCount);
          If (t^.PrecedenceCount = 0) Then AddToQueue (t);

          p := p^.NextPredSucc;
        End; { while p }

{============================================Page 16==================================================}
    End; { while Queue }
End; { ScheduleNetwork }

Procedure DetectCycles;
Var cycle: boolean;
Begin
  cycle := FALSE;

  Task := FirstTask;
  While (Task <> Nil) Do
    Begin
      If (Not Task^.WasQueued) Then
        Begin
          If (Not cycle) Then
            Begin
              writeln;
              writeln ('*** Network cycle found involving some of these tasks:');
            End;

          cycle := TRUE;
          writeln (' ', Task^.TaskCode);
        End;

      Task := Task^.NextTask;
    End; { while Task }

  If cycle Then
    Begin
      writeln (StdErr);
      writeln (StdErr, '*** The project network contains a cycle');
      writeln (StdErr, ' (Refer to the output file)');
      flush (StdErr);
      halt;
    End;
End;

Procedure MonteCarloSimulation;
Var ba, ma, bm, a3, m2, b3, m2over2, m3over3,
  r, flt, tbf, use, totuse: single;
Begin
  writeln (StdErr);
  write (StdErr, 'Monte-Carlo Simulation # ', Simulation);

  NetworkFinish := 0.0;
  MinResourceFinIdx := 0;

  If ((PrintResources) Or (ResourceLimit > 0)) Then
    Begin
      For FinIdx := 0 To MaxResourceFinIdx Do
        Begin
          ResourceUse [FinIdx] := 0.0; { Clear current simulation values }
        End;
    End;

  Task := FirstTask; { Compute simulated durations }
  While (Task <> Nil) Do
    Begin
      With Task^ Do
        Begin
          ba := DurPessimistic - DurOptimistic;
          ma := DurLikely - DurOptimistic;
          bm := DurPessimistic - DurLikely;

          If (ba <= 0.0) Then SimulatedDur := DurLikely { "constant" }
          Else
            Begin
              If (Simulation = 1) Then
                Begin { Use expected value }
                  SimulatedDur := 0.0;
                  m2 := DurLikely * DurLikely;
                  m2over2 := m2 / 2.0;
                  m3over3 := (m2 * DurLikely) / 3.0;
                  If (ma > 0.0) Then
                    Begin
                      a3 := DurOptimistic * DurOptimistic * DurOptimistic;
                      SimulatedDur := SimulatedDur + ((2.0 / (ma * ba)) *
                                      (m3over3 - (DurOptimistic * m2over2) + (a3 / 6.0)));

{============================================Page 17==================================================}
                    End;
                  If (bm > 0.0) Then
                    Begin
                      b3 := DurPessimistic * DurPessimistic * DurPessimistic;
                      SimulatedDur := SimulatedDur + ((2.0 / (bm * ba)) *
                                      (m3over3 - (DurPessimistic * m2over2) + (b3 / 6.0)));
                    End;
                End
              Else
                Begin
                  r := Random;
                  If (r <= (ma / ba)) Then SimulatedDur := DurOptimistic +
                                                           sqrt (r * ma * ba)
                  Else SimulatedDur := DurPessimistic -
                                       sqrt ((1.0 - r) * bm * ba);
                End;
            End; { else not a "constant" distribution }

          If (Simulation = 1) Then CalculatedMean := SimulatedDur;

          WasQueued := FALSE; { Used to detect cycles in network }

        End; { with Task }

      Task := Task^.NextTask;
    End; { while Task }

  ScheduleNetwork (FORWARD_PASS);

  If (Simulation = 1) Then DetectCycles; { Aborts if any found }
  ScheduleNetwork (BACKWARD_PASS);

  Task := FirstTask; { Aocumulate mean values, and milestone finishes }
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          tbf := TimeB [FORWARD_PASS];
          MeanDur := MeanDur + SimulatedDur;
          MeanFinish := MeanFinish + tbf;

          { For the following, the Backward Pass values are "back-timed" from }
          { the Network Finish value }

          flt := (NetworkFinish - TimeA [BACKWARD_PASS]) - tbf;
          If (abs (flt) < EPSILON) Then flt := 0.0;
          MeanFloat := MeanFloat + flt;
          If (flt = 0.0) Then Criticality := Criticality + 1.0;

          If (Milestone <> Nil) Then
            Begin
              FinIdx := round (tbf);
              With Milestone^ Do
                Begin
                  FinishDistribution [FinIdx] := succ (FinishDistribution [FinIdx]);
                  If (FinIdx < MinFinIdx) Then MinFinIdx := FinIdx;
                  If (FinIdx > MaxFinIdx) Then MaxFinIdx := FinIdx;
                End; { with Milestone }
            End; { if milestone distribution }
        End; { with Task }

      Task := Task^.NextTask;
    End; { while Task }

  If ((PrintResources) Or (ResourceLimit > 0)) Then
    Begin
      totuse := 0.0;

      For FinIdx := 0 To MaxResourceFinIdx Do
        Begin
          use := ResourceUse [FinIdx];
          If (use > MaxResourceUse [FinIdx]) Then
            Begin
              MaxResourceUse [FinIdx] := use;
            End; { if new maximum }

{============================================Page 18==================================================}
          MeanResourceUse [FinIdx] := MeanResourceUse [FinIdx] + use;
          totuse := totuse + use;
        End; { for FinIdx }

      If (totuse > HighResourceUse) Then HighResourceUse := totuse;
      If (totuse < LowResourceUse) Then LowResourceUse := totuse;
    End; { if printing resources }

  MeanNetworkFinish := MeanNetworkFinish + NetworkFinish;
  write (StdErr, ' Finish = ', NetworkFinish:5:1,
         ' Accumulated Mean = ', (MeanNetworkFinish / Simulation): 5: 1);
End; { MonteCarloSimulation }

Procedure FinalizeMeanValues;
Begin
  Task := FirstTask; { Divide out # Simulations from accumulated "means" }
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          MeanDur := MeanDur / NbrSimulations;
          MeanFinish := MeanFinish / NbrSimulations;
          MeanFloat := MeanFloat / NbrSimulations;
          MeanDelay := MeanDelay / NbrSimulations;
          Criticality := Criticality / NbrSimulations;
        End; { with Task }
      Task := Task^.NextTask;
    End; { while Task }
  If ((PrintResources) Or (ResourceLimit > 0)) Then For FinIdx := 0 To MaxResourceFinIdx Do
                                                      Begin
                                                        MeanResourceUse [FinIdx] := MeanResourceUse
                                                                                    [FinIdx] /
                                                                                    NbrSimulations;
                                                      End;
  MeanNetworkFinish := MeanNetworkFinish / NbrSimulations;
End; { FinalizeMeanValues }

Procedure writeHeading;
Begin
  writeln;
  writeln;
  writeln (NetworkDescription);
  writeln;
  If (NbrSimulations = 1) Then writeln ('Results from Mean Durations')
  Else writeln ('Expected Results from ', NbrSimulations, ' Monte-Carlo Simulations');
  If (ResourceLimit > 0) Then writeln ('Resource Limit is ', ResourceLimit);
  writeln;
End; { WriteHeading }

Procedure ShowDetails;
Var ps: PredSuccPtr;
Begin
  writeln (StdErr);
  writeln (StdErr, '(Printing Details)');

  writeHeading;
  writeln ('Mean Network Finish = ', MeanNetworkFinish:5:1);

  Task := FirstTask; { Print Details for each Task }
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          writeln;
          writeln (CopyLength (TaskCode, SHORT_STR_LEN),
          BLANK, DurOptimistic: 5: 1,
                                   BLANK, DurLikely: 5: 1,
                                                        BLANK, DurPessimistic: 5: 1,
{============================================Page 19==================================================}
                                                                                  BLANK, TaskDesc);

          If (TaskResourceCount <> 1.0) Then
            Begin
              writeln (' Resource Count ', TaskResourceCount:5:1);
            End;

          writeln (' Mean Durations: Calculated ', CalculatedMean:5:1,
                   ' Simulated ', MeanDur:5:1);
          writeln (' Expected Start ', (MeanFinish - MeanDur): 5: 1,
                   CopyLength (BLANK, 12),
                   ' Expected Finish ', MeanFinish: 5:1);
          writeln (' Criticality ', Criticality:8:1,
                   ' Float ', MeanFloat:5:1,
                   ' Delay ', MeanDelay:5:1);
        End; { with Task }

      ps := Task^.FirstPred;
      While (ps <> Nil) Do
        Begin
          writeln (CopyLength (BLANK, 17),
          'Predecessor: ', ps^.PredSuccTask^.TaskCode);
          ps := ps^.NextPredSucc;
        End; { while processing predecessors }
      Task := Task^.NextTask;
    End; { while Task }
End; { ShowDetails }

Procedure WriteDecimalChar (use: single; zerochar: char);
Begin
  If (use > 0.9) Then write ('X')
  Else If (use > 0.8) Then write ('9')
  Else If (use > 0.7) Then write ('8')
  Else If (use > 0.6) Then write ('7')
  Else If (use > 0.5) Then write ('6')
  Else If (use > 0.4) Then write ('5')
  Else If (use > 0.3) Then write ('4')
  Else If (use > 0.2) Then write ('3')
  Else If (use > 0.1) Then write ('2')
  Else If (use > 0.01) Then write ('1')
  Else write (zerochar);
End; { WriteDecima1Char }

Procedure WriteTimeScale;
Var
  i: FinishIndex;
  mm, dd: integer;
Begin
  mm := StartDate Div 100;
  If (mm > 0) Then
    Begin
      write (CopyLength (BLANK, SHORT_STR_LEN));

      If (mm > 12) Then mm := 1;
      dd := StartDate Mod 100;
      i := 0;
      While (i < MeanNetworkFinish) Do
        Begin
          If (dd > DaysInMonth [mm]) Then
            Begin
              dd := dd - DaysInMonth [mm];
              mm := succ (mm);
              If (mm > 12) Then mm := 1;
            End; { correct dd }
          write (mm:2, dd:2, '!');
          i := i + 5;
          dd := dd + 7;
        End; { while }
      writeln;
    End; { if mm > 0 }

{============================================Page 20==================================================}
  write (CopyLength (BLANK, SHORT_STR_LEN),
  '....+....1....+....2....+....3',
  '....+....4....+....5....+....6....+....7');
  If (MeanNetworkFinish > 70) Then
    Begin
      write ('....+....8....+....9....+...10....+...11',
             '....+...12....+...13....+...14....+...15');
    End;
  If (MeanNetworkFinish > 150) Then
    Begin
      write ('....+...16....+...17....+...18....+...19',
             '....+...20....+...21....+...22....+...23');
    End;
  If (MeanNetworkFinish > 230) Then
    Begin
      write ('....+...24....+...25....+...26....+...27',
             '....+...28....+...29....+...30....+...3l');
    End;
  If (MeanNetworkFinish > 310) Then
    Begin
      write ('....+...32....+...33....+...34....+...35',
             '....+...36....+...37....+...38....+...39');
    End;
  writeln;
End; { WriteTimeScale }

Procedure ShowGantt;
Var st, fi, du, fl, dl, count: FinishIndex;
  crit: single;
Begin
  writeln (StdErr);
  writeln (StdErr, '(Printing Gantt chart)');

  writeHeading;
  WriteTimeScale;
  writeln;

  Task := FirstTask; { Print time-line for each Task }
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          crit := Criticality;

          st := round (MeanFinish - MeanDur);
          If (st < 0) Then st := 0;
          fi := trunc (MeanFinish + TRUNCATE_UP);
          du := fi - st;
          If (du < 1) Then du := 1;
          fl := trunc (MeanFloat + EPSILON);
          dl := trunc (MeanDelay + EPSILON);

          write (CopyLength (TaskCode, SHORT_STR_LEN));
        End; { with Task }

      For count := 1 To (st - dl) Do
        write (BLANK);
      For count := 1 To dl Do
        write ('.');
      For count := 1 To du Do
        WriteDecimalChar (crit, '+');
      If (ResourceLimit = 0) Then
        Begin { Skip float if resource-limited }
          For count := 1 To fl Do
            write ('-');
        End;
      writeln;

      Task := Task^.NextTask;
    End; { while Task }
End; { Sh0wGantt }

Procedure ShowResources;
Var linecount, line: integer;
  maxuse, totuse: single;
Begin
  writeln (StdErr);
{============================================Page 21==================================================}
  writeln (StdErr, '(Printing Resource use)');

  writeHeading;

  maxuse := 0.0;
  totuse := 0.0;
  For FinIdx := 0 To MaxResourceFinIdx Do
    Begin
      If (MaxResourceUse [FinIdx] > maxuse) Then maxuse := MaxResourceUse [FinIdx];
      totuse := totuse + MeanResourceUse [FinIdx];
    End; { for FinIdx }

  linecount := trunc (maxuse + 1.0 + EPSILON);

  writeln;
  writeln ('Expected Resource Use');
  writeln;
  WriteTimeScale;

  For line := linecount Downto 0 Do
    Begin
      write (CopyLength (BLANK, SHORT_STR_LEN));

      For FinIdx := 0 To MaxResourceFinIdx Do
        Begin
          WriteDecimalChar ((MeanResourceUse [FinIdx] - line), BLANK);
        End; { for FinIdx }

      writeln;
    End; { for line }

  writeln;
  writeln ('Expected Total Resource Use = ', totuse:7:1);

  If (NbrSimulations > 1) Then
    Begin
      writeln;
      writeln ('Maximum Resource Use');
      writeln;
      WriteTimeScale;

      For line := linecount Downto 0 Do
        Begin
          write (CopyLength (BLANK, SHORT_STR_LEN));

          For FinIdx := 0 To MaxResourceFinIdx Do
            Begin
              WriteDecimalChar ((MaxResourceUse [FinIdx] - line), BLANK);
            End; { for FinIdx }

          writeln;
        End; { for line }

      writeln;
      writeln (' Lowest Total Resource Use = ', LowResourceUse:7:1);
      writeln (' Highest Total Resource Use = ', HighResourceUse:7:1);
    End; { if multiple simulations }
End; { ShowResources }

Procedure ShowFinish;
Var count: FinishIndex;
  finstar: char;
Begin
  writeln (StdErr);
  writeln (StdErr, '(Printing Finish distributions)');

  writeHeading;
  writeln ('Distributions of Milestone Task Finish Times');
  Task := FirstTask;
  While (Task <> Nil) Do
    Begin
      With Task^ Do
        Begin
{============================================Page 22==================================================}
          If (Milestone <> Nil) Then
            Begin
              writeln;
              writeln (CopyLength (TaskCode, SHORT_STR_LEN), BLANK, TaskDesc);
              writeln;
              For FinIdx := Milestone^.MinFinIdx To Milestone^.MaxFinIdx Do
                Begin
                  If (FinIdx = round (MeanFinish)) Then finstar := '*'
                  Else finstar := BLANK;
                  write (FinIdx:5, finstar);
                  For count := 1 To Milestone^.FinishDistribution [FinIdx] Do
                    Begin
                      write (BLOB);
                    End;
                  writeln;
                End; { for FinIdx }
            End; { if milestone }
        End; { with Task }
      Task := Task^.NextTask;
    End; { while Task }
End; { ShowFinish }

Procedure WritePrnFile;
Var
  hours, rc: integer;
Begin
  writeln (StdErr);
  writeln (StdErr, '(Writing interface file SPERT.PRN)');

  assign (PrnFile, 'SPERT.PRN');
  rewrite (PrnFile);

  write (PrnFile, ' ', CopyLength (NetworkDescription, 27));
  rc := MaxResourceCount;
  While (rc > 0) Do
    Begin
      write (PrnFile, ' ', '--XX--');
      rc := pred (rc);
    End;
  writeln (PrnFile);

  writeln (PrnFile, 'P   ', 'Phase');
  writeln (PrnFile, 'A   ', 'Activity');

  Task := FirstTask; { Print activity line for each Task }
  While (Task <> Nil) Do
    Begin;
      With Task^ Do
        Begin
          hours := trunc ((8.0 * MeanDur) + EPSILON);
          If (hours < 1) Then hours := 1;

          write (PrnFile, 'T   ', CopyLength (TaskDesc, 27));
          rc := trunc (TaskResourceCount);
          If (rc = 0) Then write (PrnFile, ' ', 1:6)
          Else While (rc > 0) Do
                 Begin
                   write (PrnFile, ' ', hours:6);
                   rc := pred (rc);
                 End;
          writeln (PrnFile);
        End; { with Task }

      Task := Task^.NextTask;
    End; { while Task }

{============================================Page 23==================================================}
  writeln (PrnFile, ' ', '=== End of Project ===');
  Close (PrnFile);
End; { WritePrnFile }

{$R *.res}

Begin
  writeln (StdErr, ' ');
  writeln (StdErr, 'STOCHASTIC P.E.R.T. PROJECT MANAGEMENT  (Version ', VERSION, ')');

  If (Paramcount = 0) Then
    Begin
      TypeHelpMsg;
      writeln (StdErr, ' ');
      flush (StdErr);
      halt;
    End;

  writeln;
  writeln;
  writeln ('STOCHASTIC P.E.R.T. PROJECT MANAGEMENT');
  writeln;

  Initialize;
  ProcessInput;
  If (PrintNetwork) Then ShowNetwork;

  ClearMeanValues;
  For Simulation := 1 To NbrSimulations Do
    MonteCarloSimulation;
  writeln;
  FinalizeMeanValues;

  If (PrintDetails) Then ShowDetails;
  If (PrintGantt) Then ShowGantt;
  If (PrintResources) Then ShowResources;
  If (PrintFinish) Then ShowFinish;
  If (PrintPrn) Then WritePrnFile;
End.

