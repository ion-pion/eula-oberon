MODULE Gramatica; (* Eula Oberon: gramatica Oberon ca reguli de cod.
  Scanerul si parserul urmeaza sintaxa din raportul Oberon-07 al lui Wirth, regula cu regula.
  Extensiile Oberon-2 (LOOP, EXIT, WITH, proceduri legate de tip, CASE ... ELSE, RETURN in mijloc,
  export „-”, tablouri deschise in afara parametrilor) sunt acceptate, dar notate.
  La prima greseala parserul sare la sfarsitul textului, ca la Wirth: totul se opreste singur. *)

  IMPORT Litere;

  CONST
    MaxSrc* = 1048576; MaxTok = 400000; MaxCom = 60000; MaxLin = 200000;
    MaxU* = 20000; MaxD* = 50000; MaxImp* = 512; MaxO2* = 24;

    (* simbolurile *)
    eof = 0; ident = 1; number = 2; string = 3; illegal = 4;
    plus = 10; minus = 11; times = 12; slash = 13; not = 14; and = 15; period = 16; comma = 17; semicolon = 18; bar = 19;
    lparen = 20; rparen = 21; lbrak = 22; rbrak = 23; lbrace = 24; rbrace = 25; becomes = 26; arrow = 27;
    eql = 28; neq = 29; lss = 30; gtr = 31; leq = 32; geq = 33; upto = 34; colon = 35; dollar = 36;
    kw0 = 50;
    array = 50; begin = 51; by = 52; case = 53; const = 54; div = 55; do = 56; else = 57; elsif = 58; end = 59;
    exit = 60; for = 61; if = 62; import = 63; in = 64; is = 65; loop = 66; mod = 67; module = 68; nil = 69;
    of = 70; or = 71; pointer = 72; procedure = 73; record = 74; repeat = 75; return = 76; then = 77; to = 78;
    type = 79; until = 80; var = 81; while = 82; with = 83;
    NKW = 34;

    (* felurile unitatilor *)
    KModul* = 0; KConst* = 1; KType* = 2; KVar* = 3; KProc* = 4; KCorp* = 5; KText* = 6;

  VAR
    src*: ARRAY MaxSrc OF CHAR; n*: INTEGER;
    tk, ts, te: ARRAY MaxTok OF INTEGER; nt: INTEGER; prea: BOOLEAN;
    cs, cf: ARRAY MaxCom OF INTEGER; nc: INTEGER;
    lin: ARRAY MaxLin OF INTEGER; nlin: INTEGER;
    kw: ARRAY NKW OF ARRAY 12 OF CHAR;
    scanErr: ARRAY 64 OF CHAR;
    p, adanc: INTEGER; stop: BOOLEAN;
    (* recursivitatea, ca in ORP al lui Wirth: prin variabile procedurale *)
    exprV, statSeqV, statementV, factorV: PROCEDURE;
    typeV: PROCEDURE (param: BOOLEAN);
    procDeclV: PROCEDURE (level: INTEGER);

    (* rezultatul *)
    ok*: BOOLEAN;
    eroare*, randul*: ARRAY 600 OF CHAR;
    linie*, coloana*: INTEGER;
    modA*, modN*: INTEGER;                    (* numele modulului in src; modN = 0: nu e modul *)
    nimp*: INTEGER; impA*, impN*: ARRAY MaxImp OF INTEGER;
    no2*: INTEGER; o2fel*, o2lin*: ARRAY MaxO2 OF INTEGER;
    o2text: ARRAY 20 OF ARRAY 64 OF CHAR;
    nu*: INTEGER;
    uKind*, uFrom*, uTo*, uHead*, uNameA*, uNameN*: ARRAY MaxU OF INTEGER;   (* uNameN < 0: „?”, = 0: numele modulului *)
    uExp*, uCurat*: ARRAY MaxU OF BOOLEAN;
    nd*: INTEGER;
    dKind*, dFrom*, dTo*, dLevel*, dNameA*, dNameN*: ARRAY MaxD OF INTEGER;
    dExp*: ARRAY MaxD OF BOOLEAN;
    fel*: INTEGER;                            (* 0 modul, 1 declaratii, 2 instructiuni *)
    simboluri*: INTEGER;

  (* ---------- liniile ---------- *)

  PROCEDURE Linia*(off: INTEGER): INTEGER;    (* cate inceputuri de rand sunt <= off *)
    VAR a, b, m: INTEGER;
  BEGIN a := 0; b := nlin;
    WHILE a < b DO m := (a + b) DIV 2; IF lin[m] <= off THEN a := m + 1 ELSE b := m END END ;
    RETURN a
  END Linia;

  PROCEDURE Randul(l: INTEGER; VAR d: ARRAY OF CHAR);
    VAR a, j: INTEGER;
  BEGIN
    IF l < 1 THEN l := 1 ELSIF l > nlin THEN l := nlin END ;
    a := lin[l-1]; j := 0;
    WHILE (a < n) & (src[a] # 0AX) & (j < LEN(d) - 1) DO
      IF src[a] = 9X THEN d[j] := " "; INC(j) ELSIF src[a] # 0DX THEN d[j] := src[a]; INC(j) END ;
      INC(a)
    END ;
    d[j] := 0X
  END Randul;

  PROCEDURE Linii;
    VAR i: INTEGER;
  BEGIN nlin := 1; lin[0] := 0; i := 0;
    WHILE i < n DO
      IF (src[i] = 0AX) & (nlin < MaxLin) THEN lin[nlin] := i + 1; INC(nlin) END ;
      INC(i)
    END
  END Linii;

  PROCEDURE O2(f, off: INTEGER);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < no2) & (o2fel[i] # f) DO INC(i) END ;
    IF (i = no2) & (no2 < MaxO2) THEN o2fel[no2] := f; o2lin[no2] := Linia(off); INC(no2) END
  END O2;

  PROCEDURE O2Text*(f: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN Litere.Copy(o2text[f], d)
  END O2Text;

  (* ---------- scanerul ---------- *)

  PROCEDURE Tok(k, s, e: INTEGER);
  BEGIN
    IF nt < MaxTok - 1 THEN tk[nt] := k; ts[nt] := s; te[nt] := e; INC(nt) ELSE prea := TRUE END
  END Tok;

  PROCEDURE Lit(c: CHAR): BOOLEAN;
  BEGIN RETURN (c >= "A") & (c <= "Z") OR (c >= "a") & (c <= "z") OR (c = "_")
  END Lit;

  PROCEDURE Cif(c: CHAR): BOOLEAN;
  BEGIN RETURN (c >= "0") & (c <= "9")
  END Cif;

  PROCEDURE Hexa(c: CHAR): BOOLEAN;
  BEGIN RETURN Cif(c) OR (c >= "A") & (c <= "F")
  END Hexa;

  PROCEDURE Cuvant(s, e: INTEGER): INTEGER;
    VAR k, i, r: INTEGER;
  BEGIN r := ident;
    IF (e - s >= 2) & (e - s <= 9) & (src[s] >= "A") & (src[s] <= "Z") THEN
      k := 0;
      WHILE (r = ident) & (k < NKW) DO
        i := 0;
        WHILE (s + i < e) & (kw[k][i] = src[s+i]) DO INC(i) END ;
        IF (s + i = e) & (kw[k][i] = 0X) THEN r := kw0 + k END ;
        INC(k)
      END
    END ;
    RETURN r
  END Cuvant;

  PROCEDURE Scan;
    VAR i, s, k, nivel: INTEGER; c, q: CHAR;
  BEGIN i := 0;
    WHILE i < n DO
      c := src[i];
      IF c <= " " THEN INC(i)
      ELSE s := i;
        IF Lit(c) THEN
          WHILE (i < n) & (Lit(src[i]) OR Cif(src[i])) DO INC(i) END ;
          Tok(Cuvant(s, i), s, i)
        ELSIF Cif(c) THEN
          WHILE (i < n) & Hexa(src[i]) DO INC(i) END ;
          IF (i < n) & ((src[i] = "H") OR (src[i] = "X") OR (src[i] = "R")) THEN
            IF src[i] = "X" THEN k := string ELSE k := number END ;
            INC(i); Tok(k, s, i)
          ELSIF (i + 1 < n) & (src[i] = ".") & (src[i+1] # ".") THEN
            INC(i);
            WHILE (i < n) & Cif(src[i]) DO INC(i) END ;
            IF (i < n) & ((src[i] = "E") OR (src[i] = "D")) THEN
              INC(i);
              IF (i < n) & ((src[i] = "+") OR (src[i] = "-")) THEN INC(i) END ;
              WHILE (i < n) & Cif(src[i]) DO INC(i) END
            END ;
            Tok(number, s, i)
          ELSE Tok(number, s, i)
          END
        ELSIF c = "$" THEN                                     (* sir hexazecimal, Project Oberon 2013 *)
          INC(i);
          WHILE (i < n) & (src[i] # "$") DO INC(i) END ;
          IF i >= n THEN
            IF scanErr[0] = 0X THEN scanErr := "șir hexazecimal neînchis" END ;
            Tok(illegal, s, i)
          ELSE INC(i); Tok(string, s, i)
          END
        ELSIF (c = 22X) OR (c = "'") THEN
          q := c; INC(i);
          WHILE (i < n) & (src[i] # q) DO INC(i) END ;
          IF i >= n THEN
            IF scanErr[0] = 0X THEN scanErr := "șir neînchis" END ;
            Tok(illegal, s, i)
          ELSE INC(i); Tok(string, s, i);
            IF q = "'" THEN O2(0, s) END
          END
        ELSIF (c = "(") & (i + 1 < n) & (src[i+1] = "*") THEN
          nivel := 1; i := i + 2;
          WHILE (i < n) & (nivel > 0) DO
            IF (src[i] = "(") & (i + 1 < n) & (src[i+1] = "*") THEN INC(nivel); i := i + 2
            ELSIF (src[i] = "*") & (i + 1 < n) & (src[i+1] = ")") THEN DEC(nivel); i := i + 2
            ELSE INC(i)
            END
          END ;
          IF nivel > 0 THEN
            Tok(illegal, s, n);
            IF scanErr[0] = 0X THEN scanErr := "comentariu neînchis" END
          END ;
          IF nc < MaxCom THEN cs[nc] := s; cf[nc] := i; INC(nc) END
        ELSE INC(i);
          IF c = "+" THEN k := plus ELSIF c = "-" THEN k := minus ELSIF c = "*" THEN k := times
          ELSIF c = "/" THEN k := slash ELSIF c = "~" THEN k := not ELSIF c = "&" THEN k := and
          ELSIF c = "," THEN k := comma ELSIF c = ";" THEN k := semicolon ELSIF c = "|" THEN k := bar
          ELSIF c = "(" THEN k := lparen ELSIF c = ")" THEN k := rparen ELSIF c = "[" THEN k := lbrak
          ELSIF c = "]" THEN k := rbrak ELSIF c = "{" THEN k := lbrace ELSIF c = "}" THEN k := rbrace
          ELSIF c = "^" THEN k := arrow ELSIF c = "=" THEN k := eql ELSIF c = "#" THEN k := neq
          ELSIF c = "." THEN IF (i < n) & (src[i] = ".") THEN INC(i); k := upto ELSE k := period END
          ELSIF c = ":" THEN IF (i < n) & (src[i] = "=") THEN INC(i); k := becomes ELSE k := colon END
          ELSIF c = "<" THEN IF (i < n) & (src[i] = "=") THEN INC(i); k := leq ELSE k := lss END
          ELSIF c = ">" THEN IF (i < n) & (src[i] = "=") THEN INC(i); k := geq ELSE k := gtr END
          ELSE k := illegal
          END ;
          Tok(k, s, i)
        END
      END
    END ;
    tk[nt] := eof; ts[nt] := n; te[nt] := n; INC(nt)
  END Scan;

  (* ---------- parserul ---------- *)

  PROCEDURE Next;
  BEGIN IF tk[p] # eof THEN INC(p) END
  END Next;

  PROCEDURE PrevEnd(): INTEGER;
    VAR r: INTEGER;
  BEGIN IF p > 0 THEN r := te[p-1] ELSE r := 0 END ;
    RETURN r
  END PrevEnd;

  PROCEDURE AddText(VAR d: ARRAY OF CHAR; s, e: INTEGER);
  BEGIN
    WHILE s < e DO Litere.AddCh(d, src[s]); INC(s) END
  END AddText;

  PROCEDURE Simbol(k: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN
    IF k >= kw0 THEN Litere.Add(d, kw[k - kw0])
    ELSIF k = plus THEN Litere.Add(d, "+") ELSIF k = minus THEN Litere.Add(d, "-") ELSIF k = times THEN Litere.Add(d, "*")
    ELSIF k = slash THEN Litere.Add(d, "/") ELSIF k = not THEN Litere.Add(d, "~") ELSIF k = and THEN Litere.Add(d, "&")
    ELSIF k = period THEN Litere.Add(d, ".") ELSIF k = comma THEN Litere.Add(d, ",") ELSIF k = semicolon THEN Litere.Add(d, ";")
    ELSIF k = bar THEN Litere.Add(d, "|") ELSIF k = lparen THEN Litere.Add(d, "(") ELSIF k = rparen THEN Litere.Add(d, ")")
    ELSIF k = lbrak THEN Litere.Add(d, "[") ELSIF k = rbrak THEN Litere.Add(d, "]") ELSIF k = lbrace THEN Litere.Add(d, "{")
    ELSIF k = rbrace THEN Litere.Add(d, "}") ELSIF k = becomes THEN Litere.Add(d, ":=") ELSIF k = arrow THEN Litere.Add(d, "^")
    ELSIF k = eql THEN Litere.Add(d, "=") ELSIF k = neq THEN Litere.Add(d, "#") ELSIF k = lss THEN Litere.Add(d, "<")
    ELSIF k = gtr THEN Litere.Add(d, ">") ELSIF k = leq THEN Litere.Add(d, "<=") ELSIF k = geq THEN Litere.Add(d, ">=")
    ELSIF k = upto THEN Litere.Add(d, "..") ELSIF k = colon THEN Litere.Add(d, ":") ELSIF k = ident THEN Litere.Add(d, "un nume")
    ELSIF k = number THEN Litere.Add(d, "un număr") ELSIF k = string THEN Litere.Add(d, "un șir")
    ELSIF k = eof THEN Litere.Add(d, "sfârșitul textului") ELSE Litere.Add(d, "?")
    END
  END Simbol;

  (* ce e simbolul de acum, spus pe romaneste *)
  PROCEDURE Descrie(VAR d: ARRAY OF CHAR);
    VAR k, s, e, j: INTEGER; t: ARRAY 40 OF CHAR;
  BEGIN k := tk[p]; s := ts[p]; e := te[p];
    IF k = ident THEN Litere.Add(d, "numele „"); AddText(d, s, e); Litere.Add(d, "”")
    ELSIF k = number THEN Litere.Add(d, "numărul "); AddText(d, s, e)
    ELSIF k = string THEN Litere.Add(d, "șirul ");
      IF e - s > 30 THEN AddText(d, s, s + 30); Litere.Add(d, "…") ELSE AddText(d, s, e) END
    ELSIF k = eof THEN Litere.Add(d, "sfârșitul textului")
    ELSIF k = illegal THEN
      j := 0;
      WHILE (s + j < e) & (src[s+j] # 0AX) & (j < 20) DO t[j] := src[s+j]; INC(j) END ;
      t[j] := 0X;
      IF (s + j < e) & (src[s+j] # 0AX) THEN Litere.Add(t, "…") END ;
      IF (t[0] = 22X) OR (t[0] = "'") OR (t[0] = "$") THEN Litere.Add(d, "un șir care nu se mai închide („"); Litere.Add(d, t); Litere.Add(d, "”)")
      ELSIF (t[0] = "(") & (t[1] = "*") THEN Litere.Add(d, "un comentariu care nu se mai închide")
      ELSE Litere.Add(d, "semnul „"); Litere.Add(d, t); Litere.Add(d, "”, care nu e în Oberon")
      END
    ELSE Litere.Add(d, "„"); Simbol(k, d); Litere.Add(d, "”")
    END
  END Descrie;

  PROCEDURE Fail(msg: ARRAY OF CHAR);
  BEGIN
    IF ok THEN
      ok := FALSE;
      Litere.Copy(msg, eroare);
      linie := Linia(ts[p]);
      coloana := ts[p] - lin[linie-1] + 1;
      Randul(linie, randul)
    END ;
    stop := TRUE; p := nt - 1                                (* la Wirth: sari la sfarsit *)
  END Fail;

  PROCEDURE Expect(k: INTEGER; ce: ARRAY OF CHAR);
    VAR m: ARRAY 300 OF CHAR;
  BEGIN
    IF tk[p] = k THEN Next
    ELSIF (k = semicolon) & (tk[p] = eof) THEN Fail("aștept „;”, dar textul s-a terminat")
    ELSE m := "aștept „"; Litere.Add(m, ce); Litere.Add(m, "”, am găsit "); Descrie(m); Fail(m)
    END
  END Expect;

  (* intoarce indexul simbolului cu numele, sau -1 *)
  PROCEDURE Ident(): INTEGER;
    VAR r: INTEGER; m: ARRAY 300 OF CHAR;
  BEGIN r := -1;
    IF tk[p] = ident THEN r := p; Next
    ELSIF tk[p] >= kw0 THEN m := "aici trebuie un nume, dar „"; Litere.Add(m, kw[tk[p] - kw0]); Litere.Add(m, "” e cuvânt rezervat"); Fail(m)
    ELSE m := "aici trebuie un nume, am găsit "; Descrie(m); Fail(m)
    END ;
    RETURN r
  END Ident;

  PROCEDURE Acelasi(a, b: INTEGER): BOOLEAN;   (* doua nume (simboluri) la fel? *)
    VAR i, la, lb: INTEGER; r: BOOLEAN;
  BEGIN
    IF (a < 0) OR (b < 0) THEN r := FALSE
    ELSE la := te[a] - ts[a]; lb := te[b] - ts[b]; r := la = lb; i := 0;
      WHILE r & (i < la) DO r := src[ts[a]+i] = src[ts[b]+i]; INC(i) END
    END ;
    RETURN r
  END Acelasi;

  PROCEDURE ExportMark(): BOOLEAN;
    VAR r: BOOLEAN;
  BEGIN r := FALSE;
    IF tk[p] = times THEN Next; r := TRUE
    ELSIF tk[p] = minus THEN O2(6, ts[p]); Next; r := TRUE
    END ;
    RETURN r
  END ExportMark;

  PROCEDURE Qualident;
    VAR x: INTEGER;
  BEGIN x := Ident();
    IF (tk[p] = period) & (tk[p+1] = ident) THEN Next; Next END
  END Qualident;

  PROCEDURE AddUnit(kind, nameTok, from, to, head: INTEGER; exp: BOOLEAN);
  BEGIN
    IF nu < MaxU THEN
      uKind[nu] := kind; uFrom[nu] := from; uTo[nu] := to; uHead[nu] := head; uExp[nu] := exp; uCurat[nu] := TRUE;
      IF nameTok >= 0 THEN uNameA[nu] := ts[nameTok]; uNameN[nu] := te[nameTok] - ts[nameTok] ELSE uNameA[nu] := 0; uNameN[nu] := 0 END ;
      INC(nu)
    END
  END AddUnit;

  PROCEDURE AddDecl(kind, nameTok: INTEGER; exp: BOOLEAN; from, to, level: INTEGER);
  BEGIN
    IF (nd < MaxD) & (nameTok >= 0) THEN
      dKind[nd] := kind; dNameA[nd] := ts[nameTok]; dNameN[nd] := te[nameTok] - ts[nameTok]; dExp[nd] := exp;
      dFrom[nd] := from; dTo[nd] := to; dLevel[nd] := level; INC(nd)
    END
  END AddDecl;

  (* sfarsitul randului, ca sa prinda si comentariul de pe acelasi rand *)
  PROCEDURE LinieSf(off: INTEGER): INTEGER;
    VAR i, a, b, m, e, k: INTEGER; nl: BOOLEAN;
  BEGIN i := off;
    WHILE (i < n) & ((src[i] = " ") OR (src[i] = 9X)) DO INC(i) END ;
    IF (i + 1 < n) & (src[i] = "(") & (src[i+1] = "*") THEN
      a := 0; b := nc;
      WHILE a < b DO m := (a + b) DIV 2; IF cs[m] < i THEN a := m + 1 ELSE b := m END END ;
      IF (a < nc) & (cs[a] = i) THEN
        e := cf[a]; nl := FALSE; k := i;
        WHILE k < e DO IF src[k] = 0AX THEN nl := TRUE END ; INC(k) END ;
        IF ~nl THEN off := e END
      END
    END ;
    RETURN off
  END LinieSf;

  PROCEDURE Imp;
    VAR a: INTEGER;
  BEGIN a := Ident();
    IF tk[p] = becomes THEN Next; a := Ident() END ;
    IF ~stop & (nimp < MaxImp) & (a >= 0) THEN impA[nimp] := ts[a]; impN[nimp] := te[a] - ts[a]; INC(nimp) END
  END Imp;

  (* DeclarationSequence; la nivelul 0 fiecare declaratie devine o unitate de memorie *)
  PROCEDURE DeclSeq(level: INTEGER);
    VAR k, rang, ordine, s0, ds, de, fel, nd0, i, cnt: INTEGER; gata, e: BOOLEAN;
      nume: ARRAY 64 OF INTEGER; exp: ARRAY 64 OF BOOLEAN;
  BEGIN ordine := 0; gata := FALSE;
    WHILE ~gata DO
      k := tk[p];
      IF (k = const) OR (k = type) OR (k = var) THEN
        IF k = const THEN rang := 1 ELSIF k = type THEN rang := 2 ELSE rang := 3 END ;
        IF rang < ordine THEN O2(2, ts[p]) END ;
        IF rang > ordine THEN ordine := rang END ;
        s0 := ts[p]; Next;
        IF k = const THEN fel := KConst ELSIF k = type THEN fel := KType ELSE fel := KVar END ;
        nd0 := nd;
        WHILE tk[p] = ident DO
          ds := ts[p]; cnt := 0;
          nume[0] := Ident(); exp[0] := ExportMark(); cnt := 1;
          IF k = var THEN
            WHILE tk[p] = comma DO Next;
              IF cnt < 64 THEN nume[cnt] := Ident(); exp[cnt] := ExportMark(); INC(cnt) ELSE i := Ident(); e := ExportMark() END
            END
          END ;
          IF k = var THEN Expect(colon, ":"); typeV(FALSE)
          ELSE
            IF tk[p] = becomes THEN
              IF k = const THEN Fail("la constante se scrie „=”, nu „:=”") ELSE Fail("la tipuri se scrie „=”, nu „:=”") END
            END ;
            Expect(eql, "=");
            IF k = const THEN exprV ELSE typeV(FALSE) END
          END ;
          Expect(semicolon, ";");
          IF ~stop THEN
            de := LinieSf(PrevEnd());
            FOR i := 0 TO cnt - 1 DO AddDecl(fel, nume[i], exp[i], ds, de, level) END ;
            IF (level = 0) & (k = type) THEN AddUnit(KType, nume[0], ds, de, de, exp[0]) END
          END
        END ;
        IF ~stop & (level = 0) & (k # type) & (nd > nd0) THEN
          e := FALSE;
          FOR i := nd0 TO nd - 1 DO IF dExp[i] THEN e := TRUE END END ;
          AddUnit(fel, -1, s0, PrevEnd(), PrevEnd(), e);
          uNameA[nu-1] := dNameA[nd0]; uNameN[nu-1] := dNameN[nd0]
        END
      ELSIF k = procedure THEN
        ordine := 4; procDeclV(level); Expect(semicolon, ";")
      ELSE gata := TRUE
      END
    END
  END DeclSeq;

  PROCEDURE FPSection;
    VAR x: INTEGER;
  BEGIN
    IF tk[p] = var THEN Next
    ELSIF tk[p] = const THEN O2(8, ts[p]); Next
    END ;
    x := Ident();
    WHILE tk[p] = comma DO Next; x := Ident() END ;
    Expect(colon, ":");
    WHILE tk[p] = array DO
      Next;
      IF tk[p] = lbrak THEN O2(9, ts[p]);
        WHILE (tk[p] # rbrak) & (tk[p] # eof) DO Next END ;
        Next
      END ;
      IF tk[p] # of THEN O2(10, ts[p]); exprV END ;
      Expect(of, "OF")
    END ;
    IF tk[p] = ident THEN Qualident ELSE typeV(TRUE) END
  END FPSection;

  PROCEDURE FormalParams;
  BEGIN Expect(lparen, "(");
    IF tk[p] # rparen THEN
      FPSection;
      WHILE tk[p] = semicolon DO Next; FPSection END
    END ;
    Expect(rparen, ")");
    IF tk[p] = colon THEN Next;
      IF tk[p] = ident THEN Qualident ELSE O2(7, ts[p]); typeV(TRUE) END
    END
  END FormalParams;

  PROCEDURE ProcDecl(level: INTEGER);
    VAR s0, name, n2, head, a, x: INTEGER; inainte, exp: BOOLEAN; m: ARRAY 300 OF CHAR;
  BEGIN s0 := ts[p]; Next;
    IF tk[p] = lparen THEN                                   (* Oberon-2: PROCEDURE (self: T) Nume *)
      O2(3, ts[p]); Next;
      IF tk[p] = var THEN Next END ;
      x := Ident(); Expect(colon, ":"); x := Ident(); Expect(rparen, ")")
    END ;
    inainte := FALSE;
    IF tk[p] = arrow THEN O2(4, ts[p]); inainte := TRUE; Next
    ELSIF (tk[p] = minus) OR (tk[p] = times) OR (tk[p] = plus) THEN Next
    END ;
    name := Ident(); exp := ExportMark();
    IF tk[p] = lparen THEN FormalParams END ;
    IF tk[p] = string THEN                                   (* voc: PROCEDURE -Nume(...) "cod C" *)
      O2(5, s0); Next;
      IF ~stop THEN AddDecl(KProc, name, exp, s0, PrevEnd(), level);
        IF level = 0 THEN AddUnit(KProc, name, s0, PrevEnd(), PrevEnd(), exp) END
      END
    ELSIF inainte THEN
      IF ~stop THEN AddDecl(KProc, name, exp, s0, PrevEnd(), level);
        IF level = 0 THEN AddUnit(KProc, name, s0, PrevEnd(), PrevEnd(), exp) END
      END
    ELSE
      Expect(semicolon, ";");
      head := LinieSf(PrevEnd());
      INC(adanc);
      DeclSeq(level + 1);
      IF tk[p] = begin THEN Next; a := adanc; adanc := 0; statSeqV; adanc := a END ;
      IF tk[p] = return THEN Next; exprV END ;
      Expect(end, "END");
      n2 := Ident();
      IF ~stop & ~Acelasi(name, n2) THEN
        DEC(p); m := "procedura se numește „"; AddText(m, ts[name], te[name]); Litere.Add(m, "”, dar END e urmat de „");
        AddText(m, ts[n2], te[n2]); Litere.Add(m, "”"); Fail(m)
      END ;
      DEC(adanc);
      IF ~stop THEN AddDecl(KProc, name, exp, s0, PrevEnd(), level);
        IF level = 0 THEN AddUnit(KProc, name, s0, PrevEnd(), head, exp) END
      END
    END
  END ProcDecl;

  PROCEDURE Type(param: BOOLEAN);
    VAR x: INTEGER; e: BOOLEAN; m: ARRAY 300 OF CHAR;
  BEGIN
    IF tk[p] = ident THEN Qualident
    ELSIF tk[p] = array THEN
      Next;
      IF tk[p] = of THEN IF ~param THEN O2(11, ts[p]) END
      ELSE exprV; WHILE tk[p] = comma DO Next; exprV END
      END ;
      Expect(of, "OF"); typeV(param)
    ELSIF tk[p] = record THEN
      Next;
      IF tk[p] = lbrak THEN O2(12, ts[p]); WHILE (tk[p] # rbrak) & (tk[p] # eof) DO Next END ; Next END ;
      IF tk[p] = lparen THEN Next; Qualident; Expect(rparen, ")") END ;
      REPEAT
        IF tk[p] = ident THEN
          x := Ident(); e := ExportMark();
          WHILE tk[p] = comma DO Next; x := Ident(); e := ExportMark() END ;
          Expect(colon, ":"); typeV(FALSE)
        END ;
        e := tk[p] = semicolon;
        IF e THEN Next END
      UNTIL ~e;
      Expect(end, "END")
    ELSIF tk[p] = pointer THEN
      Next;
      IF tk[p] = lbrak THEN O2(13, ts[p]); WHILE (tk[p] # rbrak) & (tk[p] # eof) DO Next END ; Next END ;
      Expect(to, "TO"); typeV(FALSE)
    ELSIF tk[p] = procedure THEN
      Next;
      IF tk[p] = lparen THEN FormalParams END
    ELSE m := "aici aștept un tip (un nume, ARRAY, RECORD, POINTER sau PROCEDURE), am găsit "; Descrie(m); Fail(m)
    END
  END Type;

  (* ---------- instructiunile ---------- *)

  PROCEDURE StatSeq;
    VAR k: INTEGER; gata: BOOLEAN; m: ARRAY 300 OF CHAR;
  BEGIN statementV; gata := FALSE;
    WHILE ~gata DO
      IF tk[p] = semicolon THEN Next; statementV
      ELSE k := tk[p];
        IF (k = ident) OR (k = if) OR (k = while) OR (k = repeat) OR (k = for) OR (k = case) OR (k = loop) OR (k = with) OR (k = exit) THEN
          m := "lipsește „;” înaintea lui "; Descrie(m); Fail(m)
        END ;
        gata := TRUE
      END
    END
  END StatSeq;

  PROCEDURE Designator;
    VAR x, k: INTEGER; gata: BOOLEAN;
  BEGIN x := Ident(); gata := FALSE;
    WHILE ~gata DO
      k := tk[p];
      IF (k = period) & (tk[p+1] = ident) THEN Next; Next
      ELSIF k = lbrak THEN Next; exprV; WHILE tk[p] = comma DO Next; exprV END ; Expect(rbrak, "]")
      ELSIF k = arrow THEN Next
      ELSIF k = lparen THEN
        Next;
        IF tk[p] # rparen THEN exprV; WHILE tk[p] = comma DO Next; exprV END END ;
        Expect(rparen, ")")
      ELSIF k = dollar THEN O2(19, ts[p]); Next
      ELSE gata := TRUE
      END
    END
  END Designator;

  PROCEDURE Eticheta;
  BEGIN exprV; IF tk[p] = upto THEN Next; exprV END
  END Eticheta;

  PROCEDURE Caz;
  BEGIN
    IF (tk[p] # bar) & (tk[p] # else) & (tk[p] # end) THEN
      Eticheta;
      WHILE tk[p] = comma DO Next; Eticheta END ;
      Expect(colon, ":"); statSeqV
    END
  END Caz;

  PROCEDURE Garda;
  BEGIN Qualident; Expect(colon, ":"); Qualident; Expect(do, "DO"); statSeqV
  END Garda;

  PROCEDURE Statement;
    VAR s, x: INTEGER;
  BEGIN s := ts[p];
    IF tk[p] = ident THEN
      Designator;
      IF tk[p] = becomes THEN Next; exprV
      ELSIF tk[p] = eql THEN Fail("la atribuire se scrie „:=”, nu „=”")
      END
    ELSIF tk[p] = if THEN
      Next; INC(adanc);
      exprV; Expect(then, "THEN"); statSeqV;
      WHILE tk[p] = elsif DO Next; exprV; Expect(then, "THEN"); statSeqV END ;
      IF tk[p] = else THEN Next; statSeqV END ;
      Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = case THEN
      Next; INC(adanc);
      exprV; Expect(of, "OF");
      Caz;
      WHILE tk[p] = bar DO Next; Caz END ;
      IF tk[p] = else THEN O2(14, ts[p]); Next; statSeqV END ;
      Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = while THEN
      Next; INC(adanc);
      exprV; Expect(do, "DO"); statSeqV;
      WHILE tk[p] = elsif DO Next; exprV; Expect(do, "DO"); statSeqV END ;
      Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = repeat THEN
      Next; INC(adanc);
      statSeqV; Expect(until, "UNTIL"); exprV; DEC(adanc)
    ELSIF tk[p] = for THEN
      Next; INC(adanc);
      x := Ident(); Expect(becomes, ":="); exprV; Expect(to, "TO"); exprV;
      IF tk[p] = by THEN Next; exprV END ;
      Expect(do, "DO"); statSeqV; Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = loop THEN
      O2(15, s); Next; INC(adanc); statSeqV; Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = exit THEN
      O2(16, s); Next
    ELSIF tk[p] = with THEN
      O2(17, s); Next; INC(adanc);
      Garda;
      WHILE tk[p] = bar DO Next; Garda END ;
      IF tk[p] = else THEN Next; statSeqV END ;
      Expect(end, "END"); DEC(adanc)
    ELSIF tk[p] = return THEN
      Next;
      IF (tk[p] # semicolon) & (tk[p] # end) & (tk[p] # else) & (tk[p] # elsif) & (tk[p] # until) & (tk[p] # bar) THEN exprV END ;
      IF ~stop & ~((adanc = 0) & (tk[p] = end)) THEN O2(18, s) END
    END                                                      (* altfel: instructiunea vida *)
  END Statement;

  (* ---------- expresiile ---------- *)

  PROCEDURE Term;
  BEGIN factorV;
    WHILE (tk[p] = times) OR (tk[p] = slash) OR (tk[p] = div) OR (tk[p] = mod) OR (tk[p] = and) DO Next; factorV END
  END Term;

  PROCEDURE SimpleExpr;
  BEGIN
    IF (tk[p] = plus) OR (tk[p] = minus) THEN Next END ;
    Term;
    WHILE (tk[p] = plus) OR (tk[p] = minus) OR (tk[p] = or) DO Next; Term END
  END SimpleExpr;

  PROCEDURE Expr;
    VAR k: INTEGER;
  BEGIN SimpleExpr; k := tk[p];
    IF (k = eql) OR (k = neq) OR (k = lss) OR (k = leq) OR (k = gtr) OR (k = geq) OR (k = in) OR (k = is) THEN Next; SimpleExpr
    ELSIF k = becomes THEN Fail("„:=” nu poate sta într-o expresie; pentru egalitate se scrie „=”")
    END
  END Expr;

  PROCEDURE Factor;
    VAR m: ARRAY 300 OF CHAR;
  BEGIN
    IF (tk[p] = number) OR (tk[p] = string) OR (tk[p] = nil) THEN Next
    ELSIF tk[p] = ident THEN Designator
    ELSIF tk[p] = lbrace THEN
      Next;
      IF tk[p] # rbrace THEN Eticheta; WHILE tk[p] = comma DO Next; Eticheta END END ;
      Expect(rbrace, "}")
    ELSIF tk[p] = lparen THEN Next; exprV; Expect(rparen, ")")
    ELSIF tk[p] = not THEN Next; factorV
    ELSE m := "aici aștept o expresie, am găsit "; Descrie(m); Fail(m)
    END
  END Factor;

  (* ---------- modulul ---------- *)

  PROCEDURE Module;
    VAR s0, name, n2, e: INTEGER; m: ARRAY 300 OF CHAR;
  BEGIN s0 := ts[p];
    Expect(module, "MODULE");
    IF tk[p] = times THEN Next END ;                          (* MODULE* (modul de pornire) *)
    name := Ident();
    IF ~stop & (name >= 0) THEN modA := ts[name]; modN := te[name] - ts[name] END ;
    IF tk[p] = lbrak THEN O2(1, ts[p]); WHILE (tk[p] # rbrak) & (tk[p] # eof) DO Next END ; Expect(rbrak, "]") END ;
    Expect(semicolon, ";");
    IF tk[p] = import THEN
      Next; Imp;
      WHILE tk[p] = comma DO Next; Imp END ;
      Expect(semicolon, ";")
    END ;
    IF ~stop THEN AddUnit(KModul, name, s0, PrevEnd(), PrevEnd(), TRUE) END ;
    DeclSeq(0);
    IF tk[p] = begin THEN
      e := ts[p]; Next; statSeqV;
      IF ~stop THEN AddUnit(KCorp, name, e, PrevEnd(), PrevEnd(), FALSE) END
    END ;
    Expect(end, "END");
    e := ts[p];
    n2 := Ident();
    IF ~stop & ~Acelasi(name, n2) THEN
      DEC(p); m := "modulul se numește „"; AddText(m, ts[name], te[name]); Litere.Add(m, "”, dar END e urmat de „");
      AddText(m, ts[n2], te[n2]); Litere.Add(m, "”"); Fail(m)
    END ;
    Expect(period, ".");
    IF ~stop THEN
      IF (nu > 0) & (uKind[nu-1] = KCorp) THEN uTo[nu-1] := PrevEnd()
      ELSE
        IF e - 4 < 0 THEN AddUnit(KCorp, name, e, PrevEnd(), PrevEnd(), FALSE) ELSE AddUnit(KCorp, name, e - 4, PrevEnd(), PrevEnd(), FALSE) END ;
        uHead[nu-1] := PrevEnd()
      END
    END
  END Module;

  (* ---------- dupa parsare ---------- *)

  PROCEDURE Schimba(i, j: INTEGER);
    VAR x: INTEGER; b: BOOLEAN;
  BEGIN
    x := uKind[i]; uKind[i] := uKind[j]; uKind[j] := x;
    x := uFrom[i]; uFrom[i] := uFrom[j]; uFrom[j] := x;
    x := uTo[i]; uTo[i] := uTo[j]; uTo[j] := x;
    x := uHead[i]; uHead[i] := uHead[j]; uHead[j] := x;
    x := uNameA[i]; uNameA[i] := uNameA[j]; uNameA[j] := x;
    x := uNameN[i]; uNameN[i] := uNameN[j]; uNameN[j] := x;
    b := uExp[i]; uExp[i] := uExp[j]; uExp[j] := b;
    b := uCurat[i]; uCurat[i] := uCurat[j]; uCurat[j] := b
  END Schimba;

  PROCEDURE DoarCuvant(a, b: INTEGER): BOOLEAN;   (* src[a, b), fara spatii la capete, e CONST/TYPE/VAR? *)
    VAR r: BOOLEAN;
  BEGIN
    WHILE (a < b) & (src[a] <= " ") DO INC(a) END ;
    WHILE (b > a) & (src[b-1] <= " ") DO DEC(b) END ;
    r := FALSE;
    IF (b - a = 5) & (src[a] = "C") & (src[a+1] = "O") & (src[a+2] = "N") & (src[a+3] = "S") & (src[a+4] = "T") THEN r := TRUE
    ELSIF (b - a = 4) & (src[a] = "T") & (src[a+1] = "Y") & (src[a+2] = "P") & (src[a+3] = "E") THEN r := TRUE
    ELSIF (b - a = 3) & (src[a] = "V") & (src[a+1] = "A") & (src[a+2] = "R") THEN r := TRUE
    ELSIF b = a THEN r := TRUE
    END ;
    RETURN r
  END DoarCuvant;

  (* fiecare unitate isi ia si comentariul de deasupra *)
  PROCEDURE Comentarii;
    VAR i, j, prev, from, c, a, b, m, ls, k: INTEGER; gata, gol: BOOLEAN;
  BEGIN
    i := 1;                                                  (* sortare stabila dupa inceput *)
    WHILE i < nu DO
      j := i;
      WHILE (j > 0) & (uFrom[j-1] > uFrom[j]) DO Schimba(j-1, j); DEC(j) END ;
      INC(i)
    END ;
    prev := 0; i := 0;
    WHILE i < nu DO
      IF uKind[i] = KCorp THEN
        IF uTo[i] > prev THEN prev := uTo[i] END
      ELSE
        from := uFrom[i];
        a := 0; b := nc;                                     (* ultimul comentariu care se termina pana la from *)
        WHILE a < b DO m := (a + b) DIV 2; IF cf[m] <= from THEN a := m + 1 ELSE b := m END END ;
        c := a - 1; gata := FALSE;
        WHILE ~gata & (c >= 0) DO
          IF cs[c] < prev THEN gata := TRUE
          ELSIF cf[c] > from THEN DEC(c)
          ELSIF cf[c] - cs[c] > 800 THEN gata := TRUE           (* licentele lungi nu sunt despre unitate *)
          ELSE
            IF DoarCuvant(cf[c], from) THEN from := cs[c] END ;
            DEC(c)
          END
        END ;
        ls := from;
        WHILE (ls > 0) & (src[ls-1] # 0AX) DO DEC(ls) END ;
        gol := TRUE; k := ls;
        WHILE k < from DO IF src[k] > " " THEN gol := FALSE END ; INC(k) END ;
        IF gol THEN from := ls END ;
        uFrom[i] := from;
        IF uTo[i] > prev THEN prev := uTo[i] END
      END ;
      INC(i)
    END
  END Comentarii;

  PROCEDURE Spatiu(c: CHAR): BOOLEAN;   (* \s din Java *)
  BEGIN RETURN (c = " ") OR (c = 9X) OR (c = 0AX) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX)
  END Spatiu;

  PROCEDURE Proc(i: INTEGER): BOOLEAN;  (* „PROCEDURE” la src[i]? *)
    VAR k: INTEGER; w: ARRAY 12 OF CHAR;
  BEGIN w := "PROCEDURE"; k := 0;
    WHILE (k < 9) & (i + k < n) & (src[i+k] = w[k]) DO INC(k) END ;
    RETURN k = 9
  END Proc;

  (* dupa o greseala, restul fisierului se taie la fiecare „PROCEDURE” de la inceput de rand (unitati necurate) *)
  PROCEDURE Restul;
    VAR from, a, ls, j, k, s, e, h, na, cnt, i: INTEGER;
      st, sa, sn: ARRAY 4096 OF INTEGER; exp: BOOLEAN;
  BEGIN
    IF nu = 0 THEN from := 0 ELSE from := uTo[nu-1] END ;
    IF (from >= 0) & (from < n) THEN
      cnt := 0; a := from;
      ls := a;                                               (* primul inceput de rand >= a *)
      IF (ls > 0) & (src[ls-1] # 0AX) THEN WHILE (ls < n) & (src[ls-1] # 0AX) DO INC(ls) END END ;
      WHILE (ls < n) & (cnt < 4096) DO
        j := ls; k := 0;
        WHILE (k < 4) & (j < n) & ((src[j] = " ") OR (src[j] = 9X)) DO INC(j); INC(k) END ;
        IF Proc(j) THEN
          j := j + 9;
          WHILE (j < n) & Spatiu(src[j]) DO INC(j) END ;
          IF (j < n) & ((src[j] = "-") OR (src[j] = "*") OR (src[j] = "^") OR (src[j] = "+")) THEN INC(j) END ;
          WHILE (j < n) & Spatiu(src[j]) DO INC(j) END ;
          na := j;
          IF (j < n) & Lit(src[j]) THEN WHILE (j < n) & (Lit(src[j]) OR Cif(src[j])) DO INC(j) END END ;
          st[cnt] := ls; sa[cnt] := na; sn[cnt] := j - na; INC(cnt);
          ls := j;
          IF (ls > 0) & (src[ls-1] # 0AX) THEN WHILE (ls < n) & (src[ls-1] # 0AX) DO INC(ls) END END
        ELSE
          INC(ls); WHILE (ls < n) & (src[ls-1] # 0AX) DO INC(ls) END
        END
      END ;
      IF cnt = 0 THEN
        IF n - from > 40 THEN AddUnit(KText, -1, from, n, n, FALSE); uCurat[nu-1] := FALSE; IF modN = 0 THEN uNameN[nu-1] := -1 END END
      ELSE
        IF st[0] - from > 40 THEN AddUnit(KText, -1, from, st[0], st[0], FALSE); uCurat[nu-1] := FALSE; IF modN = 0 THEN uNameN[nu-1] := -1 END END ;
        i := 0;
        WHILE i < cnt DO
          s := st[i];
          IF i + 1 < cnt THEN e := st[i+1] ELSE e := n END ;
          h := s; WHILE (h < n) & (src[h] # ";") DO INC(h) END ;
          IF (h >= n) OR (h > e) THEN h := e ELSE INC(h) END ;
          (* exportat? \s*PROCEDURE\s*[-^+]?\s*nume\s*\* *)
          j := s; WHILE (j < h) & Spatiu(src[j]) DO INC(j) END ;
          exp := FALSE;
          IF Proc(j) & (j + 9 <= h) THEN
            j := j + 9; WHILE (j < h) & Spatiu(src[j]) DO INC(j) END ;
            IF (j < h) & ((src[j] = "-") OR (src[j] = "^") OR (src[j] = "+")) THEN INC(j) END ;
            WHILE (j < h) & Spatiu(src[j]) DO INC(j) END ;
            IF (j < h) & Lit(src[j]) THEN
              WHILE (j < h) & (Lit(src[j]) OR Cif(src[j])) DO INC(j) END ;
              WHILE (j < h) & Spatiu(src[j]) DO INC(j) END ;
              exp := (j < h) & (src[j] = "*")
            END
          END ;
          IF nu < MaxU THEN
            uKind[nu] := KProc; uFrom[nu] := s; uTo[nu] := e; uHead[nu] := h; uExp[nu] := exp; uCurat[nu] := FALSE;
            IF sn[i] > 0 THEN uNameA[nu] := sa[i]; uNameN[nu] := sn[i] ELSE uNameA[nu] := 0; uNameN[nu] := -1 END ;
            INC(nu)
          END ;
          IF (nd < MaxD) & (sn[i] > 0) THEN
            dKind[nd] := KProc; dNameA[nd] := sa[i]; dNameN[nd] := sn[i]; dExp[nd] := exp; dFrom[nd] := s; dTo[nd] := e; dLevel[nd] := 0; INC(nd)
          END ;
          INC(i)
        END
      END
    END
  END Restul;

  (* analizeaza un text: un modul intreg, niste declaratii sau niste instructiuni *)
  PROCEDURE Analizeaza*(VAR text: ARRAY OF CHAR; len: INTEGER);
    VAR i, k: INTEGER; m: ARRAY 300 OF CHAR;
  BEGIN
    ok := TRUE; eroare[0] := 0X; randul[0] := 0X; linie := 0; coloana := 0;
    modA := 0; modN := 0; nimp := 0; no2 := 0; nu := 0; nd := 0; fel := 0; simboluri := 0;
    nt := 0; nc := 0; prea := FALSE; scanErr[0] := 0X; p := 0; adanc := 0; stop := FALSE;
    IF len > MaxSrc - 1 THEN len := MaxSrc - 1; prea := TRUE END ;
    n := len; i := 0;
    WHILE i < n DO src[i] := text[i]; INC(i) END ;
    src[n] := 0X;
    Linii; Scan;
    IF prea THEN
      ok := FALSE; eroare := "textul e prea mare pentru mine"; linie := 1; coloana := 1; Randul(1, randul); stop := TRUE
    ELSE
      k := tk[0];
      IF k # module THEN                                     (* comenzi inainte de modul („ORP.Compile @”) *)
        i := 1;
        WHILE (i < nt) & (ts[i] < 2000) & (k # module) DO
          IF (tk[i] = module) & ((ts[i] = 0) OR (src[ts[i] - 1] = 0AX)) THEN p := i; k := module END ;
          INC(i)
        END
      END ;
      IF k = module THEN fel := 0; Module                    (* dupa „END Nume.” poate urma orice *)
      ELSE
        IF (k = const) OR (k = type) OR (k = var) OR (k = procedure) THEN fel := 1; DeclSeq(0)
        ELSE fel := 2; statSeqV
        END ;
        IF tk[p] # eof THEN m := "după sfârșit mai urmează "; Descrie(m); Fail(m) END
      END
    END ;
    simboluri := nt - 1;
    Comentarii;
    IF ~ok THEN Restul END
  END Analizeaza;

  (* numele unitatii i (cu numele modulului si „?” pentru cele fara nume) *)
  PROCEDURE NumeU*(i: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN d[0] := 0X;
    IF uNameN[i] > 0 THEN AddText(d, uNameA[i], uNameA[i] + uNameN[i])
    ELSIF (uNameN[i] = 0) & (modN > 0) THEN AddText(d, modA, modA + modN)
    ELSE d := "?"
    END
  END NumeU;

  PROCEDURE Nume*(a, len: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN d[0] := 0X; AddText(d, a, a + len)
  END Nume;

BEGIN
  exprV := Expr; statSeqV := StatSeq; statementV := Statement; factorV := Factor; typeV := Type; procDeclV := ProcDecl;
  kw[0] := "ARRAY"; kw[1] := "BEGIN"; kw[2] := "BY"; kw[3] := "CASE"; kw[4] := "CONST"; kw[5] := "DIV"; kw[6] := "DO";
  kw[7] := "ELSE"; kw[8] := "ELSIF"; kw[9] := "END"; kw[10] := "EXIT"; kw[11] := "FOR"; kw[12] := "IF"; kw[13] := "IMPORT";
  kw[14] := "IN"; kw[15] := "IS"; kw[16] := "LOOP"; kw[17] := "MOD"; kw[18] := "MODULE"; kw[19] := "NIL"; kw[20] := "OF";
  kw[21] := "OR"; kw[22] := "POINTER"; kw[23] := "PROCEDURE"; kw[24] := "RECORD"; kw[25] := "REPEAT"; kw[26] := "RETURN";
  kw[27] := "THEN"; kw[28] := "TO"; kw[29] := "TYPE"; kw[30] := "UNTIL"; kw[31] := "VAR"; kw[32] := "WHILE"; kw[33] := "WITH";
  o2text[0] := "șir între apostrofuri"; o2text[1] := "opțiuni după numele modulului";
  o2text[2] := "declarații în altă ordine decât CONST, TYPE, VAR"; o2text[3] := "procedură legată de tip";
  o2text[4] := "declarație înainte („PROCEDURE ^”)"; o2text[5] := "procedură cu cod C (voc)";
  o2text[6] := "export doar pentru citire („-”)"; o2text[7] := "rezultat de tip structurat"; o2text[8] := "parametru CONST";
  o2text[9] := "opțiuni la ARRAY (voc)"; o2text[10] := "tablou cu lungime ca parametru";
  o2text[11] := "tablou deschis în afara parametrilor"; o2text[12] := "opțiuni la RECORD"; o2text[13] := "opțiuni la POINTER";
  o2text[14] := "CASE … ELSE"; o2text[15] := "LOOP"; o2text[16] := "EXIT"; o2text[17] := "WITH";
  o2text[18] := "RETURN în mijlocul procedurii"; o2text[19] := "„$” după nume"
END Gramatica.
