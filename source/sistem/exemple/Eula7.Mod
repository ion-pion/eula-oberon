(* Eula 7, scrisa in Oberon-07 (din Eula 7 v8, Java). Zece module intr-un singur fisier, in ordinea in care se
   importa unul pe altul; ultimul (Eula7) e aplicatia. O faci aplicatie cu:   apk Eula7.Mod "Eula 7"
   Datele ei stau in dosarul Eula7/ de langa: unicode.bin (felul literelor), lexicon-ro.tsv (gramatica), text.txt
   (prima ei masa). Le pune Pachet in aplicatie; ea le ia cu Conversatie.Resursa.
     E7Txt   literele si sirurile, vectori mari, tabele de cuvinte
     E7Disc  citit/scris pe disc prin tampon
     E7Gram  gramatica: 208 sutre, alternante, lexiconul
     E7Mem   memoria: frazele, formele de baza, indexul, fotografia
     E7Sor   sorobanul in a 7-a dimensiune (si geometria: spirala, fete, N7, 49 de litere)
     E7Roler Roler peste Cubicum FS: nodul si frecventa fiecarui fisier
     E7Motor motorul: candidatele, sorobanul, Opal
     E7Fire  firea: salut, nume, cine e, ce stie, ce invata
     E7Web   Faza 2, „macină”: aduce pagina, robots.txt, textul si legaturile, fisierul din Download/macinate, pasunea
     Eula7   aplicatia: Ask / Feed / Importa, butoanele geometriei
   Testata pe calculator fata de Eula 7 Java: 154 din 154 de raspunsuri identice (si nota de sub ele).
   Faza 2 (v22): „macină <adresă>”, „wiki <titlu>”, „wiki pasune N” (din legatura in legatura), „wiki stop”,
   „măcinate”, „citește N” (fara internet).
   Pion & Claude, 20.10.2026 *)

MODULE E7Txt; (* Eula 7 in Oberon: literele si sirurile. Felul fiecarui semn (litera, cifra, majuscula) si literele
  mici/mari vin din unicode.bin, un tabel facut o data din Java (aceleasi raspunsuri ca Character.isLetter & co.).
  Plus: vectori mari de intregi si de semne (pe bucati de 64 K) si Tabel = siruri unice numerotate 0, 1, 2 ...
  in ordinea in care intra (ca HashMap<String, Integer> + ArrayList<String> din Eula 7).  Pion & Claude, 20.10.2026 *)

  IMPORT Files;

  CONST B* = 65536; NB = 4096; MaxCuv* = 1024;

  TYPE
    IBloc = POINTER TO IBlocDesc;
    IBlocDesc = RECORD a: ARRAY B OF INTEGER END;
    Ints* = POINTER TO IntsDesc;
    IntsDesc* = RECORD b: ARRAY NB OF IBloc END;

    CBloc = POINTER TO CBlocDesc;
    CBlocDesc = RECORD a: ARRAY B OF CHAR END;
    Chars* = POINTER TO CharsDesc;
    CharsDesc* = RECORD b: ARRAY NB OF CBloc END;

    Tabel* = POINTER TO TabelDesc;
    TabelDesc* = RECORD
      n*: INTEGER;              (* cate siruri *)
      cap: INTEGER;             (* sloturile (putere a lui 2) *)
      slot: Ints;               (* id + 1, 0 = gol *)
      st, ln, hs: Ints;         (* unde incepe sirul in pool, cat e de lung, hash-ul lui *)
      pool: Chars; np: INTEGER;
      val*: Ints                (* o valoare pentru fiecare sir, pentru cine are nevoie *)
    END ;

  VAR fel: ARRAY 65536 OF BYTE;
    mic, mare: ARRAY 65536 OF CHAR;
    ubuf: ARRAY 65536 OF BYTE; uk: INTEGER;
    gata*: BOOLEAN;

  (* ---------- vectorii mari ---------- *)

  PROCEDURE NouInts*(): Ints;
    VAR x: Ints;
  BEGIN NEW(x); RETURN x
  END NouInts;

  PROCEDURE Ia*(x: Ints; i: INTEGER): INTEGER;
    VAR b: IBloc; r: INTEGER;
  BEGIN b := x.b[i DIV B];
    IF b = NIL THEN r := 0 ELSE r := b.a[i MOD B] END ;
    RETURN r
  END Ia;

  PROCEDURE Pune*(x: Ints; i, v: INTEGER);
    VAR k: INTEGER;
  BEGIN k := i DIV B;
    IF x.b[k] = NIL THEN NEW(x.b[k]) END ;
    x.b[k].a[i MOD B] := v
  END Pune;

  PROCEDURE NouChars*(): Chars;
    VAR x: Chars;
  BEGIN NEW(x); RETURN x
  END NouChars;

  PROCEDURE C*(x: Chars; i: INTEGER): CHAR;
    VAR b: CBloc; r: CHAR;
  BEGIN b := x.b[i DIV B];
    IF b = NIL THEN r := 0X ELSE r := b.a[i MOD B] END ;
    RETURN r
  END C;

  PROCEDURE PuneC*(x: Chars; i: INTEGER; c: CHAR);
    VAR k: INTEGER;
  BEGIN k := i DIV B;
    IF x.b[k] = NIL THEN NEW(x.b[k]) END ;
    x.b[k].a[i MOD B] := c
  END PuneC;

  (* ---------- felul semnelor (din unicode.bin) ---------- *)

  PROCEDURE Litera*(c: CHAR): BOOLEAN;     (* Character.isLetter *)
  BEGIN RETURN ODD(fel[ORD(c)])
  END Litera;

  PROCEDURE Cifra*(c: CHAR): BOOLEAN;      (* Character.isDigit *)
  BEGIN RETURN ODD(fel[ORD(c)] DIV 2)
  END Cifra;

  PROCEDURE LitCif*(c: CHAR): BOOLEAN;     (* Character.isLetterOrDigit *)
  BEGIN RETURN fel[ORD(c)] MOD 4 # 0
  END LitCif;

  PROCEDURE Majuscula*(c: CHAR): BOOLEAN;  (* Character.isUpperCase *)
  BEGIN RETURN ODD(fel[ORD(c)] DIV 4)
  END Majuscula;

  PROCEDURE Lu*(c: CHAR): BOOLEAN;         (* \p{Lu} din expresii *)
  BEGIN RETURN ODD(fel[ORD(c)] DIV 8)
  END Lu;

  PROCEDURE Cuv*(c: CHAR): BOOLEAN;        (* semn de cuvant pentru \b (litera, cifra, semn diacritic, _) *)
  BEGIN RETURN ODD(fel[ORD(c)] DIV 16)
  END Cuv;

  PROCEDURE Mic*(c: CHAR): CHAR;           (* Character.toLowerCase *)
  BEGIN RETURN mic[ORD(c)]
  END Mic;

  PROCEDURE Mare*(c: CHAR): CHAR;          (* Character.toUpperCase *)
  BEGIN RETURN mare[ORD(c)]
  END Mare;

  PROCEDURE Spatiu*(c: CHAR): BOOLEAN;     (* \s: spatiu, \t \n \v \f \r *)
  BEGIN RETURN (c = " ") OR (c >= 9X) & (c <= 0DX)
  END Spatiu;

  (* fara diacritice (doar literele mici, ca Memorie.fold): ă â -> a, î -> i, ș ş -> s, ț ţ -> t *)
  PROCEDURE Fold*(c: CHAR): CHAR;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    IF (o = 103H) OR (o = 0E2H) THEN c := "a"
    ELSIF o = 0EEH THEN c := "i"
    ELSIF (o = 219H) OR (o = 15FH) THEN c := "s"
    ELSIF (o = 21BH) OR (o = 163H) THEN c := "t"
    END ;
    RETURN c
  END Fold;

  PROCEDURE Incarca*(cale: ARRAY OF CHAR): BOOLEAN;
    VAR f: Files.File; n, i, a, b: INTEGER;

    PROCEDURE Int(): INTEGER;
      VAR x: INTEGER;
    BEGIN x := ubuf[uk] * 1000000H + ubuf[uk+1] * 10000H + ubuf[uk+2] * 100H + ubuf[uk+3]; uk := uk + 4;
      RETURN x
    END Int;

    PROCEDURE Sh(): INTEGER;
      VAR x: INTEGER;
    BEGIN x := ubuf[uk] * 100H + ubuf[uk+1]; uk := uk + 2;
      RETURN x
    END Sh;

  BEGIN gata := FALSE;
    FOR i := 0 TO 65535 DO mic[i] := CHR(i); mare[i] := CHR(i) END ;
    IF Files.Exists(cale) THEN
      f := Files.Open(cale);
      IF f # NIL THEN
        Files.ReadBytes(f, fel, n);
        IF n = 65536 THEN
          Files.ReadBytes(f, ubuf, n); uk := 0;
          a := Int();
          FOR i := 1 TO a DO b := Sh(); mic[b] := CHR(Sh()) END ;
          a := Int();
          FOR i := 1 TO a DO b := Sh(); mare[b] := CHR(Sh()) END ;
          gata := uk <= n
        END ;
        Files.Close(f)
      END
    END ;
    RETURN gata
  END Incarca;

  (* ---------- siruri ---------- *)

  PROCEDURE Len*(s: ARRAY OF CHAR): INTEGER;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END ;
    RETURN i
  END Len;

  PROCEDURE Copy*(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) & (i < LEN(d) - 1) DO d[i] := s[i]; INC(i) END ;
    d[i] := 0X
  END Copy;

  PROCEDURE Add*(VAR d: ARRAY OF CHAR; s: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN i := Len(d); j := 0;
    WHILE (j < LEN(s)) & (s[j] # 0X) & (i < LEN(d) - 1) DO d[i] := s[j]; INC(i); INC(j) END ;
    d[i] := 0X
  END Add;

  PROCEDURE AddCh*(VAR d: ARRAY OF CHAR; c: CHAR);
    VAR i: INTEGER;
  BEGIN i := Len(d);
    IF i < LEN(d) - 1 THEN d[i] := c; d[i+1] := 0X END
  END AddCh;

  PROCEDURE AddInt*(VAR d: ARRAY OF CHAR; x: INTEGER);
    VAR t: ARRAY 16 OF CHAR; i, q: INTEGER;
  BEGIN
    IF x = 0 THEN AddCh(d, "0")
    ELSE i := 0;
      IF x < 0 THEN AddCh(d, "-") END ;
      WHILE x # 0 DO
        q := x DIV 10;
        IF (x < 0) & (q * 10 # x) THEN q := q + 1 END ;
        t[i] := CHR(ORD("0") + ABS(x - q * 10)); INC(i); x := q
      END ;
      WHILE i > 0 DO DEC(i); AddCh(d, t[i]) END
    END
  END AddInt;

  (* String.format("%,d") cu punct in loc de virgula: 1.234.567 *)
  PROCEDURE AddNr*(VAR d: ARRAY OF CHAR; x: INTEGER);
    VAR t: ARRAY 16 OF CHAR; i, k: INTEGER;
  BEGIN
    IF x < 0 THEN AddCh(d, "-"); x := -x END ;
    i := 0;
    REPEAT t[i] := CHR(ORD("0") + x MOD 10); x := x DIV 10; INC(i) UNTIL x = 0;
    k := i;
    WHILE i > 0 DO
      DEC(i); AddCh(d, t[i]);
      IF (i > 0) & (i MOD 3 = 0) THEN AddCh(d, ".") END
    END
  END AddNr;

  PROCEDURE Eq*(a, b: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(a)) & (i < LEN(b)) & (a[i] = b[i]) & (a[i] # 0X) DO INC(i) END ;
    RETURN ((i = LEN(a)) OR (a[i] = 0X)) & ((i = LEN(b)) OR (b[i] = 0X))
  END Eq;

  PROCEDURE Incepe*(s, p: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(p)) & (p[i] # 0X) & (i < LEN(s)) & (s[i] = p[i]) DO INC(i) END ;
    RETURN (i >= LEN(p)) OR (p[i] = 0X)
  END Incepe;

  (* incepe s, de la pozitia k, cu p? *)
  PROCEDURE IncepeLa*(s: ARRAY OF CHAR; k: INTEGER; p: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(p)) & (p[i] # 0X) & (k + i < LEN(s)) & (s[k+i] = p[i]) DO INC(i) END ;
    RETURN (i >= LEN(p)) OR (p[i] = 0X)
  END IncepeLa;

  PROCEDURE Sfarsit*(s, p: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER;
  BEGIN i := Len(s); j := Len(p);
    WHILE (j > 0) & (i > 0) & (s[i-1] = p[j-1]) DO DEC(i); DEC(j) END ;
    RETURN j = 0
  END Sfarsit;

  (* pozitia lui p in s de la „de” incolo, sau -1 *)
  PROCEDURE Pos*(p, s: ARRAY OF CHAR; de: INTEGER): INTEGER;
    VAR i, j, n, m, r: INTEGER;
  BEGIN n := Len(s); m := Len(p); r := -1; i := de;
    WHILE (r < 0) & (i + m <= n) DO
      j := 0;
      WHILE (j < m) & (s[i+j] = p[j]) DO INC(j) END ;
      IF j = m THEN r := i END ;
      INC(i)
    END ;
    RETURN r
  END Pos;

  PROCEDURE Contine*(s, p: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN Pos(p, s, 0) >= 0
  END Contine;

  (* bucata s[a..b) in d *)
  PROCEDURE Sub*(s: ARRAY OF CHAR; a, b: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (a < b) & (i < LEN(d) - 1) DO d[i] := s[a]; INC(i); INC(a) END ;
    d[i] := 0X
  END Sub;

  (* String.trim: scoate ce e <= " " de la capete *)
  PROCEDURE Trim*(VAR s: ARRAY OF CHAR);
    VAR a, b, i: INTEGER;
  BEGIN b := Len(s); a := 0;
    WHILE (a < b) & (s[a] <= " ") DO INC(a) END ;
    WHILE (b > a) & (s[b-1] <= " ") DO DEC(b) END ;
    i := 0;
    WHILE a < b DO s[i] := s[a]; INC(i); INC(a) END ;
    s[i] := 0X
  END Trim;

  (* toLowerCase, semn cu semn *)
  PROCEDURE MicS*(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO s[i] := mic[ORD(s[i])]; INC(i) END
  END MicS;

  (* Memorie.fold *)
  PROCEDURE FoldS*(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO s[i] := Fold(s[i]); INC(i) END
  END FoldS;

  (* String.hashCode *)
  PROCEDURE Hash*(s: ARRAY OF CHAR): INTEGER;
    VAR h, i: INTEGER;
  BEGIN h := 0; i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO h := h * 31 + ORD(s[i]); INC(i) END ;
    RETURN h
  END Hash;

  (* intre literele dintr-o lista despartita de "|": e s chiar unul dintre ele? *)
  PROCEDURE InLista*(s, lista: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER; da, gasit: BOOLEAN;
  BEGIN i := 0; gasit := FALSE;
    WHILE ~gasit & (i < LEN(lista)) & (lista[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (i < LEN(lista)) & (lista[i] # 0X) & (lista[i] # "|") DO
        IF da & (j < LEN(s)) & (s[j] = lista[i]) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da & ((j = LEN(s)) OR (s[j] = 0X)) THEN gasit := TRUE END ;
      IF (i < LEN(lista)) & (lista[i] = "|") THEN INC(i) END
    END ;
    RETURN gasit
  END InLista;

  (* ---------- Tabel: siruri unice, numerotate in ordinea intrarii ---------- *)

  PROCEDURE NouTabel*(): Tabel;
    VAR t: Tabel;
  BEGIN NEW(t); t.n := 0; t.cap := 1024; t.slot := NouInts(); t.st := NouInts(); t.ln := NouInts(); t.hs := NouInts();
    t.pool := NouChars(); t.np := 0; t.val := NouInts();
    RETURN t
  END NouTabel;

  PROCEDURE Goleste*(t: Tabel);
  BEGIN t.n := 0; t.cap := 1024; t.slot := NouInts(); t.st := NouInts(); t.ln := NouInts(); t.hs := NouInts();
    t.pool := NouChars(); t.np := 0; t.val := NouInts()
  END Goleste;

  PROCEDURE Loc(h, cap: INTEGER): INTEGER;
  BEGIN RETURN ASR(h * 1103515245 + 12345, 7) MOD cap
  END Loc;

  PROCEDURE Acelasi(t: Tabel; id: INTEGER; s: ARRAY OF CHAR; n: INTEGER): BOOLEAN;
    VAR a, i: INTEGER; da: BOOLEAN;
  BEGIN da := Ia(t.ln, id) = n;
    IF da THEN
      a := Ia(t.st, id); i := 0;
      WHILE da & (i < n) DO da := C(t.pool, a + i) = s[i]; INC(i) END
    END ;
    RETURN da
  END Acelasi;

  (* numarul sirului s, sau -1 *)
  PROCEDURE Gaseste*(t: Tabel; s: ARRAY OF CHAR): INTEGER;
    VAR h, n, k, id, r: INTEGER;
  BEGIN n := Len(s); h := Hash(s); k := Loc(h, t.cap); r := -2;
    WHILE r = -2 DO
      id := Ia(t.slot, k) - 1;
      IF id < 0 THEN r := -1
      ELSIF (Ia(t.hs, id) = h) & Acelasi(t, id, s, n) THEN r := id
      ELSE k := (k + 1) MOD t.cap
      END
    END ;
    RETURN r
  END Gaseste;

  PROCEDURE Creste(t: Tabel);
    VAR s: Ints; id, k: INTEGER;
  BEGIN t.cap := t.cap * 2; s := NouInts();
    FOR id := 0 TO t.n - 1 DO
      k := Loc(Ia(t.hs, id), t.cap);
      WHILE Ia(s, k) # 0 DO k := (k + 1) MOD t.cap END ;
      Pune(s, k, id + 1)
    END ;
    t.slot := s
  END Creste;

  (* numarul sirului s; daca nu era, il adauga (cu urmatorul numar) *)
  PROCEDURE Adauga*(t: Tabel; s: ARRAY OF CHAR): INTEGER;
    VAR h, n, k, id, i: INTEGER;
  BEGIN id := Gaseste(t, s);
    IF id < 0 THEN
      IF 2 * (t.n + 1) > t.cap THEN Creste(t) END ;
      n := Len(s); h := Hash(s); id := t.n; INC(t.n);
      Pune(t.st, id, t.np); Pune(t.ln, id, n); Pune(t.hs, id, h);
      FOR i := 0 TO n - 1 DO PuneC(t.pool, t.np, s[i]); INC(t.np) END ;
      k := Loc(h, t.cap);
      WHILE Ia(t.slot, k) # 0 DO k := (k + 1) MOD t.cap END ;
      Pune(t.slot, k, id + 1)
    END ;
    RETURN id
  END Adauga;

  PROCEDURE Are*(t: Tabel; s: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN Gaseste(t, s) >= 0
  END Are;

  PROCEDURE Sir*(t: Tabel; id: INTEGER; VAR s: ARRAY OF CHAR);
    VAR a, n, i: INTEGER;
  BEGIN a := Ia(t.st, id); n := Ia(t.ln, id); i := 0;
    WHILE (i < n) & (i < LEN(s) - 1) DO s[i] := C(t.pool, a + i); INC(i) END ;
    s[i] := 0X
  END Sir;

  PROCEDURE Lung*(t: Tabel; id: INTEGER): INTEGER;
  BEGIN RETURN Ia(t.ln, id)
  END Lung;

  PROCEDURE SirC*(t: Tabel; id, i: INTEGER): CHAR;      (* semnul i al sirului id *)
  BEGIN RETURN C(t.pool, Ia(t.st, id) + i)
  END SirC;

  (* incepe sirul id cu p? *)
  PROCEDURE SirIncepe*(t: Tabel; id: INTEGER; p: ARRAY OF CHAR): BOOLEAN;
    VAR a, n, i: INTEGER; da: BOOLEAN;
  BEGIN a := Ia(t.st, id); n := Ia(t.ln, id); i := 0; da := TRUE;
    WHILE da & (i < LEN(p)) & (p[i] # 0X) DO da := (i < n) & (C(t.pool, a + i) = p[i]); INC(i) END ;
    RETURN da
  END SirIncepe;

  (* o lista de cuvinte despartite de spatii intra in tabel *)
  PROCEDURE Lista*(t: Tabel; s: ARRAY OF CHAR);
    VAR w: ARRAY 64 OF CHAR; i, j, id: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
      WHILE s[i] = " " DO INC(i) END ;
      j := 0;
      WHILE (i < LEN(s)) & (s[i] # 0X) & (s[i] # " ") DO w[j] := s[i]; INC(j); INC(i) END ;
      w[j] := 0X;
      IF j > 0 THEN id := Adauga(t, w) END
    END
  END Lista;

BEGIN gata := FALSE
END E7Txt.


MODULE E7Disc; (* Eula 7 in Oberon: citit si scris pe disc printr-un tampon de 64 KB (un cititor si un scriitor).
  Intregii se scriu pe 4 octeti (cel mic intai), semnele pe 2. *)

  IMPORT Files;

  CONST B = 65536;

  VAR fc, fs: Files.File;
    bc, bs: ARRAY B OF BYTE; cp, cn, sp: INTEGER;
    ok*, sok*: BOOLEAN;   (* cititorul / scriitorul inca merg *)
    citit*: INTEGER;      (* cati octeti a dat cititorul pana acum *)

  (* ---------- cititorul ---------- *)

  PROCEDURE Citeste*(nume: ARRAY OF CHAR): BOOLEAN;
  BEGIN
    IF fc # NIL THEN Files.Close(fc); fc := NIL END ;
    IF Files.Exists(nume) THEN fc := Files.Open(nume) ELSE fc := NIL END ;
    cp := 0; cn := 0; citit := 0; ok := fc # NIL;
    RETURN ok
  END Citeste;

  PROCEDURE Marime*(): INTEGER;
    VAR r: INTEGER;
  BEGIN IF fc # NIL THEN r := Files.Size(fc) ELSE r := -1 END ;
    RETURN r
  END Marime;

  (* sare la pozitia p (de la inceputul fisierului) *)
  PROCEDURE Sari*(p: INTEGER);
    VAR r: INTEGER;
  BEGIN
    IF fc # NIL THEN r := Files.Seek(fc, p); cp := 0; cn := 0; citit := p END
  END Sari;

  PROCEDURE InchideC*;
  BEGIN IF fc # NIL THEN Files.Close(fc); fc := NIL END ; ok := FALSE
  END InchideC;

  (* urmatorul octet, sau -1 la sfarsit *)
  PROCEDURE Octet*(): INTEGER;
    VAR x: INTEGER;
  BEGIN
    IF cp >= cn THEN
      cp := 0; cn := 0;
      IF ok THEN Files.ReadBytes(fc, bc, cn) END ;
      IF cn <= 0 THEN cn := 0; ok := FALSE END
    END ;
    IF cp < cn THEN x := bc[cp]; INC(cp); INC(citit) ELSE x := -1 END ;
    RETURN x
  END Octet;

  (* n octeti in b (de la 0); intoarce cati a pus *)
  PROCEDURE Octeti*(VAR b: ARRAY OF BYTE; n: INTEGER): INTEGER;
    VAR i, k: INTEGER;
  BEGIN i := 0;
    WHILE i < n DO
      IF cp >= cn THEN
        cp := 0; cn := 0;
        IF ok THEN Files.ReadBytes(fc, bc, cn) END ;
        IF cn <= 0 THEN cn := 0; ok := FALSE; n := i END
      END ;
      k := cn - cp; IF k > n - i THEN k := n - i END ;
      WHILE k > 0 DO b[i] := bc[cp]; INC(i); INC(cp); DEC(k) END
    END ;
    citit := citit + i;
    RETURN i
  END Octeti;

  PROCEDURE Int*(): INTEGER;
    VAR b0, b1, b2, b3: INTEGER;
  BEGIN b0 := Octet(); b1 := Octet(); b2 := Octet(); b3 := Octet();
    RETURN b0 + LSL(b1, 8) + LSL(b2, 16) + LSL(b3, 24)
  END Int;

  PROCEDURE Ch*(): CHAR;
    VAR a, b: INTEGER;
  BEGIN a := Octet(); b := Octet();
    RETURN CHR(a + b * 256)
  END Ch;

  PROCEDURE Sir*(VAR s: ARRAY OF CHAR);
    VAR i, n: INTEGER; c: CHAR;
  BEGIN n := Int(); i := 0;
    WHILE ok & (i < n) DO
      c := Ch();
      IF i < LEN(s) - 1 THEN s[i] := c END ;
      INC(i)
    END ;
    IF (n >= 0) & (n < LEN(s)) THEN s[n] := 0X ELSIF n < 0 THEN s[0] := 0X ELSE s[LEN(s) - 1] := 0X END
  END Sir;

  (* ---------- scriitorul ---------- *)

  PROCEDURE Scrie*(nume: ARRAY OF CHAR): BOOLEAN;
  BEGIN fs := Files.Create(nume); sp := 0; sok := fs # NIL;
    RETURN sok
  END Scrie;

  PROCEDURE Goleste;
  BEGIN
    IF sp > 0 THEN Files.WriteNBytes(fs, bs, sp); sp := 0 END
  END Goleste;

  PROCEDURE Inchide*;
  BEGIN
    IF fs # NIL THEN
      Goleste; sok := sok & (Files.Status(fs) = Files.OK);
      Files.Close(fs); fs := NIL
    END
  END Inchide;

  PROCEDURE Pune*(x: INTEGER);
  BEGIN
    IF sp = B THEN Goleste END ;
    bs[sp] := x MOD 256; INC(sp)
  END Pune;

  PROCEDURE PuneOcteti*(b: ARRAY OF BYTE; n: INTEGER);
    VAR i: INTEGER;
  BEGIN
    FOR i := 0 TO n - 1 DO
      IF sp = B THEN Goleste END ;
      bs[sp] := b[i]; INC(sp)
    END
  END PuneOcteti;

  PROCEDURE PuneInt*(x: INTEGER);
  BEGIN Pune(x MOD 256); Pune(ASR(x, 8) MOD 256); Pune(ASR(x, 16) MOD 256); Pune(ASR(x, 24) MOD 256)
  END PuneInt;

  PROCEDURE PuneCh*(c: CHAR);
  BEGIN Pune(ORD(c) MOD 256); Pune(ORD(c) DIV 256)
  END PuneCh;

  PROCEDURE PuneSir*(s: ARRAY OF CHAR);
    VAR i, n: INTEGER;
  BEGIN n := 0;
    WHILE (n < LEN(s)) & (s[n] # 0X) DO INC(n) END ;
    PuneInt(n); i := 0;
    WHILE i < n DO PuneCh(s[i]); INC(i) END
  END PuneSir;

  (* un sir ca text UTF-8 (cum il scrie Java cu getBytes("UTF-8")) *)
  PROCEDURE PuneUtf8*(s: ARRAY OF CHAR);
    VAR i, c, d: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
      c := ORD(s[i]); INC(i);
      IF c < 80H THEN Pune(c)
      ELSIF c < 800H THEN Pune(0C0H + c DIV 64); Pune(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0DC00H) & (i < LEN(s)) & (ORD(s[i]) >= 0DC00H) & (ORD(s[i]) < 0E000H) THEN
        d := ORD(s[i]); INC(i);
        c := 10000H + (c - 0D800H) * 400H + (d - 0DC00H);
        Pune(0F0H + c DIV 40000H); Pune(80H + c DIV 1000H MOD 64); Pune(80H + c DIV 64 MOD 64); Pune(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0E000H) THEN Pune(ORD("?"))
      ELSE Pune(0E0H + c DIV 1000H); Pune(80H + c DIV 64 MOD 64); Pune(80H + c MOD 64)
      END
    END
  END PuneUtf8;

  PROCEDURE Sterge*(nume: ARRAY OF CHAR);
    VAR r: INTEGER;
  BEGIN
    IF Files.Exists(nume) THEN r := Files.Delete(nume) END
  END Sterge;

  PROCEDURE Redenumeste*(de, la: ARRAY OF CHAR): BOOLEAN;
  BEGIN Sterge(la);
    RETURN Files.Rename(de, la) = Files.OK
  END Redenumeste;

  PROCEDURE Exista*(nume: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN Files.Exists(nume)
  END Exista;

  (* marimea unui fisier, fara sa-l tina deschis; -1 daca nu e *)
  PROCEDURE MarimeF*(nume: ARRAY OF CHAR): INTEGER;
    VAR f: Files.File; r: INTEGER;
  BEGIN r := -1;
    IF Files.Exists(nume) THEN
      f := Files.Open(nume);
      IF f # NIL THEN r := Files.Size(f); Files.Close(f) END
    END ;
    RETURN r
  END MarimeF;

BEGIN fc := NIL; fs := NIL; ok := FALSE; sok := FALSE
END E7Disc.


MODULE E7Gram; (* Eula 7 in Oberon: gramatica limbii romane ca reguli de cod, pe metoda lui Pāṇini (Gramatica7).
  1. Alfabetul (31 de litere) si clasele de sunete.
  2. Sūtrele de flexiune: terminatie -> terminatia formei de baza. Terminatia mai lunga e mai speciala si castiga
     (ca la Pāṇini, regula mai specifica o blocheaza pe cea generala); la aceeasi lungime, cea scrisa mai devreme.
  3. Alternantele la imbinare (sandhi): brazi -> brad, frați -> frate, școli -> școală, mese -> masă.
  4. Lista de radacini (formele de baza din lexicon): o analiza a carei forma de baza e in lista castiga.
  5. Lexiconul (forme vazute in UD) si ce a analizat deja.  208 sutre, aceleasi ca in Eula 7. *)

  IMPORT E7Txt, E7Disc;

  CONST MaxS = 256; MaxAn = 4096; PoolAn = 1048576; MaxW = E7Txt.MaxCuv;
    N* = 1; ADJ* = 2; V* = 3;

  VAR
    sDin, sIn: ARRAY MaxS OF ARRAY 16 OF CHAR; sLen, sPos: ARRAY MaxS OF INTEGER; nS: INTEGER;
    aDin, aIn: ARRAY 16 OF ARRAY 8 OF CHAR; nA: INTEGER;
    vDin, vIn: ARRAY 8 OF ARRAY 8 OF CHAR; nV: INTEGER;
    capete: ARRAY 32 OF ARRAY 8 OF CHAR; nCap: INTEGER;
    vocale: ARRAY 16 OF CHAR;

    (* analizele unei forme *)
    anSt, anLn, anPut: ARRAY MaxAn OF INTEGER; nan: INTEGER;
    anPool: ARRAY PoolAn OF CHAR; npool: INTEGER;

    lexF*, lexL, verbe, nume, radacini, cacheF, cacheL: E7Txt.Tabel;
    w, rad, r2, cand, tmp, linie: ARRAY MaxW OF CHAR;

  (* ---------- listele ---------- *)

  PROCEDURE S(pos: INTEGER; din, in: ARRAY OF CHAR);
  BEGIN E7Txt.Copy(din, sDin[nS]); E7Txt.Copy(in, sIn[nS]); sLen[nS] := E7Txt.Len(din); sPos[nS] := pos; INC(nS)
  END S;

  PROCEDURE Alt(a, b: ARRAY OF CHAR);
  BEGIN E7Txt.Copy(a, aDin[nA]); E7Txt.Copy(b, aIn[nA]); INC(nA)
  END Alt;

  PROCEDURE Voc(a, b: ARRAY OF CHAR);
  BEGIN E7Txt.Copy(a, vDin[nV]); E7Txt.Copy(b, vIn[nV]); INC(nV)
  END Voc;

  PROCEDURE Cap(a: ARRAY OF CHAR);
  BEGIN E7Txt.Copy(a, capete[nCap]); INC(nCap)
  END Cap;

  PROCEDURE Sutre;
  BEGIN nS := 0;
    S(1, "urilor", "");
    S(1, "ilor", "");
    S(1, "ilor", "e");
    S(1, "ilor", "ă");
    S(1, "elor", "ă");
    S(1, "elor", "");
    S(1, "elor", "ea");
    S(1, "iilor", "ie");
    S(1, "iilor", "iu");
    S(1, "ălor", "ă");
    S(1, "urile", "");
    S(1, "ii", "");
    S(1, "ile", "ă");
    S(1, "ile", "e");
    S(1, "ele", "ă");
    S(1, "ele", "");
    S(1, "ele", "ea");
    S(1, "iile", "ie");
    S(1, "iii", "iu");
    S(1, "ității", "itate");
    S(1, "ități", "itate");
    S(1, "itățile", "itate");
    S(1, "ităților", "itate");
    S(1, "ății", "ate");
    S(1, "ăți", "ate");
    S(1, "ățile", "ate");
    S(1, "ăților", "ate");
    S(1, "ării", "are");
    S(1, "ări", "are");
    S(1, "ările", "are");
    S(1, "ărilor", "are");
    S(1, "irii", "ire");
    S(1, "iri", "ire");
    S(1, "irile", "ire");
    S(1, "irilor", "ire");
    S(1, "erii", "ere");
    S(1, "eri", "ere");
    S(1, "erile", "ere");
    S(1, "erilor", "ere");
    S(1, "ției", "ție");
    S(1, "ții", "ție");
    S(1, "țiile", "ție");
    S(1, "țiilor", "ție");
    S(1, "ura", "ură");
    S(1, "urii", "ură");
    S(1, "uri", "ură");
    S(1, "ului", "");
    S(1, "ului", "u");
    S(1, "lui", "");
    S(1, "ei", "ă");
    S(1, "ii", "e");
    S(1, "iei", "ie");
    S(1, "elei", "ea");
    S(1, "ii", "a");
    S(1, "ul", "");
    S(1, "l", "");
    S(1, "le", "");
    S(1, "a", "ă");
    S(1, "ea", "e");
    S(1, "ia", "ie");
    S(1, "ua", "");
    S(1, "aua", "a");
    S(1, "uri", "");
    S(1, "i", "");
    S(1, "i", "e");
    S(1, "i", "ă");
    S(1, "e", "ă");
    S(1, "e", "");
    S(1, "ele", "ea");
    S(1, "ii", "ie");
    S(1, "ii", "iu");
    S(1, "i", "a");
    S(2, "ată", "at");
    S(2, "ate", "at");
    S(2, "ați", "at");
    S(2, "ită", "it");
    S(2, "ite", "it");
    S(2, "iți", "it");
    S(2, "ută", "ut");
    S(2, "ute", "ut");
    S(2, "uți", "ut");
    S(2, "âtă", "ât");
    S(2, "âte", "ât");
    S(2, "ătoare", "ător");
    S(2, "ători", "ător");
    S(2, "toare", "tor");
    S(2, "tori", "tor");
    S(2, "oare", "or");
    S(2, "ală", "al");
    S(2, "ale", "al");
    S(2, "ali", "al");
    S(2, "ică", "ic");
    S(2, "ice", "ic");
    S(2, "ici", "ic");
    S(2, "ivă", "iv");
    S(2, "ive", "iv");
    S(2, "ivi", "iv");
    S(2, "antă", "ant");
    S(2, "ante", "ant");
    S(2, "anți", "ant");
    S(2, "entă", "ent");
    S(2, "ente", "ent");
    S(2, "enți", "ent");
    S(2, "oasă", "os");
    S(2, "oase", "os");
    S(2, "oși", "os");
    S(2, "ească", "esc");
    S(2, "ești", "esc");
    S(2, "ică", "ic");
    S(2, "ice", "ic");
    S(2, "ici", "ic");
    S(2, "ă", "");
    S(2, "e", "");
    S(2, "i", "");
    S(2, "ă", "u");
    S(2, "i", "e");
    S(2, "ie", "iu");
    S(2, "ii", "iu");
    S(2, "eie", "eu");
    S(2, "ee", "eu");
    S(2, "ei", "eu");
    S(3, "ează", "a");
    S(3, "ez", "a");
    S(3, "ezi", "a");
    S(3, "eze", "a");
    S(3, "ăm", "a");
    S(3, "ați", "a");
    S(3, "at", "a");
    S(3, "ată", "a");
    S(3, "ate", "a");
    S(3, "ând", "a");
    S(3, "ându", "a");
    S(3, "am", "a");
    S(3, "ai", "a");
    S(3, "au", "a");
    S(3, "ase", "a");
    S(3, "aseră", "a");
    S(3, "asem", "a");
    S(3, "ară", "a");
    S(3, "arăm", "a");
    S(3, "ă", "a");
    S(3, "e", "a");
    S(3, "i", "a");
    S(3, "a", "a");
    S(3, "ea", "a");
    S(3, "eau", "a");
    S(3, "ezică", "a");
    S(3, "esc", "i");
    S(3, "ești", "i");
    S(3, "ește", "i");
    S(3, "ească", "i");
    S(3, "im", "i");
    S(3, "iți", "i");
    S(3, "it", "i");
    S(3, "ită", "i");
    S(3, "ite", "i");
    S(3, "ind", "i");
    S(3, "indu", "i");
    S(3, "ise", "i");
    S(3, "iseră", "i");
    S(3, "isem", "i");
    S(3, "ea", "i");
    S(3, "eau", "i");
    S(3, "eam", "i");
    S(3, "i", "i");
    S(3, "iră", "i");
    S(3, "irăm", "i");
    S(3, "ăsc", "î");
    S(3, "ăști", "î");
    S(3, "ăște", "î");
    S(3, "ască", "î");
    S(3, "âm", "î");
    S(3, "âți", "î");
    S(3, "ât", "î");
    S(3, "âtă", "î");
    S(3, "âte", "î");
    S(3, "âse", "î");
    S(3, "ârăm", "î");
    S(3, "â", "î");
    S(3, "ut", "ea");
    S(3, "ut", "e");
    S(3, "ută", "ea");
    S(3, "ută", "e");
    S(3, "ute", "ea");
    S(3, "ute", "e");
    S(3, "uți", "e");
    S(3, "ând", "ea");
    S(3, "ând", "e");
    S(3, "em", "ea");
    S(3, "em", "e");
    S(3, "eți", "ea");
    S(3, "eți", "e");
    S(3, "eam", "ea");
    S(3, "eam", "e");
    S(3, "eau", "ea");
    S(3, "eau", "e");
    S(3, "use", "ea");
    S(3, "use", "e");
    S(3, "useră", "e");
    S(3, "u", "ea");
    S(3, "u", "e");
    S(3, "e", "e");
    S(3, "s", "e");
    S(3, "să", "e");
    S(3, "se", "e");
    S(3, "ă", "ea");
    S(3, "ă", "e");
    S(3, "ea", "ea");
  END Sutre;

  PROCEDURE Alternante;
  BEGIN nA := 0; nV := 0; nCap := 0;
    Alt("ț", "t");
    Alt("z", "d");
    Alt("ș", "s");
    Alt("ști", "st");
    Alt("șt", "st");
    Alt("ști", "sc");
    Alt("șt", "sc");
    Alt("ci", "c");
    Alt("gi", "g");
    Alt("ț", "c");
    Alt("z", "g");
    Voc("o", "oa");
    Voc("e", "ea");
    Voc("e", "a");
    Voc("ă", "a");
    Voc("i", "ea");
    Voc("oa", "o");
    Voc("ea", "e");
    Cap("ență");
    Cap("anță");
    Cap("ință");
    Cap("ție");
    Cap("ie");
    Cap("are");
    Cap("ire");
    Cap("ere");
    Cap("ime");
    Cap("ism");
    Cap("ist");
    Cap("os");
    Cap("al");
    Cap("tor");
    Cap("iv");
    Cap("ant");
    Cap("ent");
    Cap("ea");
    Cap("iu");
    Cap("ui");
    Cap("ar");
  END Alternante;

  (* ---------- 1. sunetele ---------- *)

  PROCEDURE Vocala*(c: CHAR): BOOLEAN;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (vocale[i] # 0X) & (vocale[i] # c) DO INC(i) END ;
    RETURN vocale[i] # 0X
  END Vocala;

  (* ş ţ (cu sedila) -> ș ț (cu virgula); litere mici; „-ntinde” = „întinde” *)
  PROCEDURE Norm*(f: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i, j: INTEGER; c: CHAR;
  BEGIN i := 0; j := 0;
    IF (LEN(f) > 0) & (f[0] = "-") THEN d[0] := CHR(0EEH); i := 1; j := 1 END ;
    WHILE (i < LEN(f)) & (f[i] # 0X) & (j < LEN(d) - 1) DO
      c := E7Txt.Mic(f[i]);
      IF c = CHR(15FH) THEN c := CHR(219H) ELSIF c = CHR(163H) THEN c := CHR(21BH) ELSIF c = CHR(0E3H) THEN c := CHR(103H) END ;
      d[j] := c; INC(i); INC(j)
    END ;
    d[j] := 0X
  END Norm;

  (* ---------- 4. analiza ---------- *)

  PROCEDURE AreCapDeBaza(s: ARRAY OF CHAR): BOOLEAN;
    VAR i, n: INTEGER; da: BOOLEAN;
  BEGIN da := FALSE; i := 0; n := E7Txt.Len(s);
    WHILE ~da & (i < nCap) DO
      IF E7Txt.Sfarsit(s, capete[i]) & (n > E7Txt.Len(capete[i]) + 2) THEN da := TRUE END ;
      INC(i)
    END ;
    RETURN da
  END AreCapDeBaza;

  PROCEDURE Egal(k: INTEGER; s: ARRAY OF CHAR; n: INTEGER): BOOLEAN;
    VAR i, a: INTEGER; da: BOOLEAN;
  BEGIN da := anLn[k] = n; a := anSt[k]; i := 0;
    WHILE da & (i < n) DO da := anPool[a + i] = s[i]; INC(i) END ;
    RETURN da
  END Egal;

  (* aceeasi forma de baza poate veni din mai multe sutre: ramane cea mai puternica *)
  PROCEDURE AdaugaAn(s: ARRAY OF CHAR; putere: INTEGER; fara: BOOLEAN);
    VAR n, k, i: INTEGER;
  BEGIN n := E7Txt.Len(s);
    IF fara OR (n >= 2) THEN
      k := 0;
      WHILE (k < nan) & ~Egal(k, s, n) DO INC(k) END ;
      IF k < nan THEN
        IF anPut[k] < putere THEN anPut[k] := putere END
      ELSIF (nan < MaxAn) & (npool + n <= PoolAn) THEN
        anSt[nan] := npool; anLn[nan] := n; anPut[nan] := putere; INC(nan);
        FOR i := 0 TO n - 1 DO anPool[npool] := s[i]; INC(npool) END
      END
    END
  END AdaugaAn;

  (* pozitia vocalei v in ultima silaba a radacinii (ultimul grup de vocale), sau -1 *)
  PROCEDURE UltimaVocala(r: ARRAY OF CHAR; v: ARRAY OF CHAR): INTEGER;
    VAR e, b, k, i, j, n, m: INTEGER; da: BOOLEAN;
  BEGIN e := E7Txt.Len(r) - 1;
    WHILE (e >= 0) & ~Vocala(r[e]) DO DEC(e) END ;
    k := -1;
    IF e >= 0 THEN
      b := e;
      WHILE (b > 0) & Vocala(r[b-1]) DO DEC(b) END ;
      n := e + 1 - b; m := E7Txt.Len(v);
      i := n - m;                       (* lastIndexOf in grup *)
      WHILE (k < 0) & (i >= 0) DO
        j := 0; da := TRUE;
        WHILE da & (j < m) DO da := r[b + i + j] = v[j]; INC(j) END ;
        IF da THEN k := b + i END ;
        DEC(i)
      END
    END ;
    RETURN k
  END UltimaVocala;

  (* d := s fara ultimele k semne, plus a, plus b *)
  PROCEDURE Fa(s: ARRAY OF CHAR; k: INTEGER; a, b: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  BEGIN E7Txt.Sub(s, 0, E7Txt.Len(s) - k, d); E7Txt.Add(d, a); E7Txt.Add(d, b)
  END Fa;

  (* toate analizele posibile, de la cea mai speciala la cea mai generala (sortare stabila) *)
  PROCEDURE Analize(forma: ARRAY OF CHAR);
    VAR o, n, ln, a, k, put, i, j, p, ps: INTEGER;
  BEGIN Norm(forma, w); n := E7Txt.Len(w); nan := 0; npool := 0;
    IF AreCapDeBaza(w) THEN AdaugaAn(w, 35000, TRUE) ELSE AdaugaAn(w, 9000, TRUE) END ;
    FOR o := 0 TO nS - 1 DO
      ln := sLen[o];
      IF (n - ln >= 2) & E7Txt.Sfarsit(w, sDin[o]) THEN
        E7Txt.Sub(w, 0, n - ln, rad); put := 10000 * ln - o;
        Fa(rad, 0, sIn[o], "", cand); AdaugaAn(cand, put, FALSE);
        FOR a := 0 TO nA - 1 DO
          IF E7Txt.Sfarsit(rad, aDin[a]) & (E7Txt.Len(rad) > E7Txt.Len(aDin[a])) THEN
            Fa(rad, E7Txt.Len(aDin[a]), aIn[a], sIn[o], cand); AdaugaAn(cand, put - 3000, FALSE)
          END
        END ;
        FOR a := 0 TO nV - 1 DO
          k := UltimaVocala(rad, vDin[a]);
          IF k >= 0 THEN
            E7Txt.Sub(rad, 0, k, r2); E7Txt.Add(r2, vIn[a]);
            E7Txt.Sub(rad, k + E7Txt.Len(vDin[a]), E7Txt.Len(rad), tmp); E7Txt.Add(r2, tmp);
            Fa(r2, 0, sIn[o], "", cand); AdaugaAn(cand, put - 4000, FALSE);
            FOR j := 0 TO nA - 1 DO
              IF E7Txt.Sfarsit(r2, aDin[j]) & (E7Txt.Len(r2) > E7Txt.Len(aDin[j])) THEN
                Fa(r2, E7Txt.Len(aDin[j]), aIn[j], sIn[o], cand); AdaugaAn(cand, put - 6000, FALSE)
              END
            END
          END
        END
      END
    END ;
    (* sortare stabila dupa putere, descrescator (insertie) *)
    FOR i := 1 TO nan - 1 DO
      p := anPut[i]; a := anSt[i]; ps := anLn[i]; j := i - 1;
      WHILE (j >= 0) & (anPut[j] < p) DO anPut[j+1] := anPut[j]; anSt[j+1] := anSt[j]; anLn[j+1] := anLn[j]; DEC(j) END ;
      anPut[j+1] := p; anSt[j+1] := a; anLn[j+1] := ps
    END
  END Analize;

  PROCEDURE AnSir(k: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < anLn[k]) & (i < LEN(d) - 1) DO d[i] := anPool[anSt[k] + i]; INC(i) END ;
    d[i] := 0X
  END AnSir;

  (* forma de baza: intai o analiza din lista de radacini (cea mai speciala); altfel cea mai speciala *)
  PROCEDURE Lema(forma: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR k, r: INTEGER;
  BEGIN Analize(forma);
    IF radacini.n = 0 THEN
      IF nan > 1 THEN AnSir(1, d) ELSE AnSir(0, d) END
    ELSE
      r := -1; k := 0;
      WHILE (r < 0) & (k < nan) DO
        AnSir(k, d);
        IF E7Txt.Are(radacini, d) THEN r := k END ;
        INC(k)
      END ;
      IF r < 0 THEN AnSir(0, d) END
    END
  END Lema;

  (* ---------- 5. lexiconul ---------- *)

  PROCEDURE AdaugaRadacina(r: ARRAY OF CHAR);
    VAR id: INTEGER;
  BEGIN Norm(r, tmp); id := E7Txt.Adauga(radacini, tmp)
  END AdaugaRadacina;

  (* un rand din lexicon-ro.tsv: forma, parte de vorbire (UPOS), lema, ... *)
  PROCEDURE Rand(VAR l: ARRAY OF CHAR);
    VAR c: ARRAY 5 OF INTEGER; k, i, id, lid: INTEGER; f, up, le: ARRAY MaxW OF CHAR;
  BEGIN
    IF l[0] # "#" THEN
      k := 0; i := 0;
      WHILE (l[i] # 0X) & (k < 5) DO IF l[i] = 9X THEN c[k] := i; INC(k) END ; INC(i) END ;
      IF k >= 2 THEN
        E7Txt.Sub(l, 0, c[0], tmp); Norm(tmp, f);
        E7Txt.Sub(l, c[0] + 1, c[1], up);
        IF k >= 3 THEN E7Txt.Sub(l, c[1] + 1, c[2], tmp) ELSE E7Txt.Sub(l, c[1] + 1, E7Txt.Len(l), tmp) END ;
        Norm(tmp, le);
        IF ~E7Txt.Are(lexF, f) THEN
          id := E7Txt.Adauga(lexF, f); lid := E7Txt.Adauga(lexL, le); E7Txt.Pune(lexF.val, id, lid)
        END ;
        IF E7Txt.Eq(up, "VERB") OR E7Txt.Eq(up, "AUX") THEN id := E7Txt.Adauga(verbe, f) END ;
        IF E7Txt.Eq(up, "NOUN") OR E7Txt.Eq(up, "PROPN") THEN id := E7Txt.Adauga(nume, f) END ;
        IF E7Txt.Eq(up, "NOUN") OR E7Txt.Eq(up, "VERB") OR E7Txt.Eq(up, "ADJ") OR E7Txt.Eq(up, "PROPN") THEN AdaugaRadacina(le) END
      END
    END
  END Rand;

  (* lexicon-ro.tsv, UTF-8, un rand pe linie *)
  PROCEDURE Incarca*(cale: ARRAY OF CHAR): BOOLEAN;
    VAR b, c, n: INTEGER; ok: BOOLEAN;
  BEGIN ok := E7Disc.Citeste(cale);
    IF ok THEN
      n := 0; b := E7Disc.Octet();
      WHILE b >= 0 DO
        IF b < 80H THEN c := b; b := E7Disc.Octet()
        ELSIF b < 0E0H THEN c := (b MOD 32) * 64 + E7Disc.Octet() MOD 64; b := E7Disc.Octet()
        ELSIF b < 0F0H THEN c := (b MOD 16) * 1000H; c := c + (E7Disc.Octet() MOD 64) * 64; c := c + E7Disc.Octet() MOD 64; b := E7Disc.Octet()
        ELSE c := 0FFFDH; b := E7Disc.Octet()
        END ;
        IF c = 0AH THEN linie[n] := 0X; Rand(linie); n := 0
        ELSIF n < MaxW - 1 THEN linie[n] := CHR(c); INC(n)
        END
      END ;
      IF n > 0 THEN linie[n] := 0X; Rand(linie) END ;
      E7Disc.InchideC
    END ;
    RETURN ok
  END Incarca;

  (* forma de baza: lexiconul, altfel sutrele + radacinile; tinuta minte (pana la 400.000 de forme) *)
  PROCEDURE Baza*(forma: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR id, k: INTEGER; f: ARRAY MaxW OF CHAR;
  BEGIN Norm(forma, f);
    id := E7Txt.Gaseste(cacheF, f);
    IF id >= 0 THEN E7Txt.Sir(cacheL, E7Txt.Ia(cacheF.val, id), d)
    ELSE
      id := E7Txt.Gaseste(lexF, f);
      IF id >= 0 THEN E7Txt.Sir(lexL, E7Txt.Ia(lexF.val, id), d)
      ELSIF E7Txt.Len(f) <= 3 THEN E7Txt.Copy(f, d)
      ELSE Lema(f, d)
      END ;
      IF cacheF.n > 400000 THEN E7Txt.Goleste(cacheF); E7Txt.Goleste(cacheL) END ;
      id := E7Txt.Adauga(cacheF, f); k := E7Txt.Adauga(cacheL, d); E7Txt.Pune(cacheF.val, id, k)
    END
  END Baza;

  PROCEDURE Verb*(forma: ARRAY OF CHAR): BOOLEAN;
    VAR f: ARRAY MaxW OF CHAR; r: BOOLEAN;
  BEGIN Norm(forma, f);
    IF E7Txt.Are(verbe, f) THEN r := TRUE
    ELSIF E7Txt.Are(lexF, f) THEN r := FALSE
    ELSE
      r := (E7Txt.Len(f) > 4) & (E7Txt.Sfarsit(f, "ează") OR E7Txt.Sfarsit(f, "ește") OR E7Txt.Sfarsit(f, "esc")
        OR E7Txt.Sfarsit(f, "eau") OR E7Txt.Sfarsit(f, "ăm") OR E7Txt.Sfarsit(f, "ați") OR E7Txt.Sfarsit(f, "ară")
        OR E7Txt.Sfarsit(f, "iră") OR E7Txt.Sfarsit(f, "it") OR E7Txt.Sfarsit(f, "at") OR E7Txt.Sfarsit(f, "ut"))
    END ;
    RETURN r
  END Verb;

  (* forma e un substantiv sau un nume propriu in lexicon (exact, fara Norm) *)
  PROCEDURE Nume*(forma: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN E7Txt.Are(nume, forma)
  END Nume;

BEGIN
  vocale := "aăâeiîou";
  Sutre; Alternante;
  lexF := E7Txt.NouTabel(); lexL := E7Txt.NouTabel(); verbe := E7Txt.NouTabel(); nume := E7Txt.NouTabel();
  radacini := E7Txt.NouTabel(); cacheF := E7Txt.NouTabel(); cacheL := E7Txt.NouTabel()
END E7Gram.


MODULE E7Mem; (* Eula 7 in Oberon: memoria. Doar frazele (text UTF-8, una dupa alta) si, pentru fiecare fraza,
  formele de baza ale cuvintelor cu sens. Indexul (forma de baza -> frazele) se reface din ele.
  Asa incap zeci de milioane de semne in telefon. Textul sta in bucati de 64 KB, ca paginile din Files al lui Wirth. *)

  IMPORT E7Txt, E7Gram, E7Disc;

  CONST B = 65536; NB = 4096; MaxW = E7Txt.MaxCuv; REC* = 1EX;
    MAGIC = 45374F42H; VER = 1;

  TYPE BBloc = POINTER TO BBlocDesc;
    BBlocDesc = RECORD a: ARRAY B OF BYTE END ;
    Arata* = PROCEDURE (procent: INTEGER);

  VAR
    txt: ARRAY NB OF BBloc; T*: INTEGER;                 (* textul frazelor, UTF-8 *)
    ns*: INTEGER; sFrom, sTo, sRec, sLa, sLn: E7Txt.Ints;   (* frazele *)
    ul: E7Txt.Ints; nul: INTEGER;                         (* formele de baza ale fiecarei fraze, una dupa alta *)
    nrec*: INTEGER; recA, recN: E7Txt.Ints; srcPool: E7Txt.Chars; nsrc: INTEGER;   (* bucatile mancate *)
    lems*, fd: E7Txt.Tabel;                               (* formele de baza; fara diacritice -> prima *)
    pHead, pTail, pCnt, pS, pNext: E7Txt.Ints; npost: INTEGER;   (* forma -> frazele (in ordine) *)
    stop, cerere: E7Txt.Tabel;
    corp*, aux: E7Txt.Chars; corpN*: INTEGER;            (* bucata de text care intra *)
    tokP: ARRAY 262144 OF CHAR; tokA*, tokN*: ARRAY 65536 OF INTEGER; ntok*, ntp: INTEGER;
    cuv, baza, fw: ARRAY MaxW OF CHAR;
    idsF: ARRAY 65536 OF INTEGER;
    arata: Arata;
    fx: ARRAY 8192 OF CHAR;
    inapoi: INTEGER;

  (* ---------- cuvintele ---------- *)

  PROCEDURE Fold*(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) & (i < LEN(d) - 1) DO d[i] := E7Txt.Fold(s[i]); INC(i) END ;
    d[i] := 0X
  END Fold;

  PROCEDURE Cerere*(w: ARRAY OF CHAR): BOOLEAN;     (* „descrie”, „explică”, „spune-mi” nu sunt subiectul *)
  BEGIN Fold(w, fw); RETURN E7Txt.Are(cerere, fw)
  END Cerere;

  PROCEDURE Stop*(w: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN E7Txt.Are(stop, w)
  END Stop;

  PROCEDURE Continut*(w: ARRAY OF CHAR): BOOLEAN;
    VAR r: BOOLEAN;
  BEGIN r := E7Txt.Len(w) >= 3;
    IF r THEN r := ~E7Txt.Are(stop, w); IF r THEN Fold(w, fw); r := ~E7Txt.Are(stop, fw) END END ;
    RETURN r
  END Continut;

  PROCEDURE PuneTok;
  BEGIN
    IF ntok < LEN(tokA) THEN tokA[ntok] := ntp; tokN[ntok] := 0; INC(ntok) END
  END PuneTok;

  (* cuvintele unei fraze, cu litere mici (ş ţ -> ș ț); in tokP, tokA, tokN, ntok *)
  PROCEDURE Tokeni*(s: ARRAY OF CHAR);
    VAR i, n, w: INTEGER; c: CHAR;
  BEGIN ntok := 0; ntp := 0; n := E7Txt.Len(s); w := 0;
    FOR i := 0 TO n DO
      IF i < n THEN c := E7Txt.Mic(s[i]) ELSE c := " " END ;
      IF c = CHR(15FH) THEN c := CHR(219H) ELSIF c = CHR(163H) THEN c := CHR(21BH) END ;
      IF E7Txt.LitCif(c) THEN
        IF w = 0 THEN PuneTok END ;
        IF (ntp < LEN(tokP)) & (ntok > 0) THEN tokP[ntp] := c; INC(ntp); INC(tokN[ntok-1]) END ;
        INC(w)
      ELSE w := 0
      END
    END
  END Tokeni;

  PROCEDURE Tok*(k: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < tokN[k]) & (i < LEN(d) - 1) DO d[i] := tokP[tokA[k] + i]; INC(i) END ;
    d[i] := 0X
  END Tok;

  PROCEDURE Lema*(id: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN E7Txt.Sir(lems, id, d)
  END Lema;

  PROCEDURE NrLeme*(): INTEGER;
  BEGIN RETURN lems.n
  END NrLeme;

  PROCEDURE IdOf(lem: ARRAY OF CHAR): INTEGER;
    VAR id, k: INTEGER;
  BEGIN id := E7Txt.Gaseste(lems, lem);
    IF id < 0 THEN
      id := E7Txt.Adauga(lems, lem);
      Fold(lem, fw);
      IF ~E7Txt.Are(fd, fw) THEN k := E7Txt.Adauga(fd, fw); E7Txt.Pune(fd.val, k, id) END
    END ;
    RETURN id
  END IdOf;

  (* id-ul formei de baza a unui cuvant din intrebare (si fara diacritice); -1 daca nu e in memorie *)
  PROCEDURE Cauta*(cuvant: ARRAY OF CHAR): INTEGER;
    VAR id: INTEGER; b, f: ARRAY MaxW OF CHAR;
  BEGIN E7Gram.Baza(cuvant, b);
    id := E7Txt.Gaseste(lems, b);
    IF id < 0 THEN
      Fold(b, f); id := E7Txt.Gaseste(fd, f);
      IF id >= 0 THEN id := E7Txt.Ia(fd.val, id)
      ELSE
        Fold(cuvant, f); id := E7Txt.Gaseste(fd, f);
        IF id >= 0 THEN id := E7Txt.Ia(fd.val, id) END
      END
    END ;
    RETURN id
  END Cauta;

  (* ---------- frazele ---------- *)

  PROCEDURE PuneOctet(x: INTEGER);
    VAR k: INTEGER;
  BEGIN k := T DIV B;
    IF txt[k] = NIL THEN NEW(txt[k]) END ;
    txt[k].a[T MOD B] := x; INC(T)
  END PuneOctet;

  PROCEDURE Octet(i: INTEGER): INTEGER;
  BEGIN RETURN txt[i DIV B].a[i MOD B]
  END Octet;

  PROCEDURE Posteaza(id, s: INTEGER);
    VAR p, t: INTEGER;
  BEGIN p := npost; INC(npost);
    E7Txt.Pune(pS, p, s);
    t := E7Txt.Ia(pTail, id);
    IF t = 0 THEN E7Txt.Pune(pHead, id, p + 1) ELSE E7Txt.Pune(pNext, t - 1, p + 1) END ;
    E7Txt.Pune(pTail, id, p + 1);
    E7Txt.Pune(pCnt, id, E7Txt.Ia(pCnt, id) + 1)
  END Posteaza;

  PROCEDURE PostN*(id: INTEGER): INTEGER;
  BEGIN RETURN E7Txt.Ia(pCnt, id)
  END PostN;

  PROCEDURE Prima*(id: INTEGER): INTEGER;     (* prima postare (sau -1) *)
  BEGIN RETURN E7Txt.Ia(pHead, id) - 1
  END Prima;

  PROCEDURE Urm*(p: INTEGER): INTEGER;
  BEGIN RETURN E7Txt.Ia(pNext, p) - 1
  END Urm;

  PROCEDURE PF*(p: INTEGER): INTEGER;        (* fraza postarii p *)
  BEGIN RETURN E7Txt.Ia(pS, p)
  END PF;

  (* fraza [a, b) din buf (\n = spatiu) intra in memorie *)
  PROCEDURE AdaugaFraza(buf: E7Txt.Chars; a, b, rec: INTEGER);
    VAR i, c, d, w, id, k, n0: INTEGER; ch: CHAR; da: BOOLEAN;
  BEGIN
    E7Txt.Pune(sFrom, ns, T);
    i := a;
    WHILE i < b DO
      ch := E7Txt.C(buf, i); IF ch = 0AX THEN ch := " " END ;
      c := ORD(ch); INC(i);
      IF c < 80H THEN PuneOctet(c)
      ELSIF c < 800H THEN PuneOctet(0C0H + c DIV 64); PuneOctet(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0DC00H) & (i < b) & (ORD(E7Txt.C(buf, i)) >= 0DC00H) & (ORD(E7Txt.C(buf, i)) < 0E000H) THEN
        d := ORD(E7Txt.C(buf, i)); INC(i);
        c := 10000H + (c - 0D800H) * 400H + (d - 0DC00H);
        PuneOctet(0F0H + c DIV 40000H); PuneOctet(80H + c DIV 1000H MOD 64); PuneOctet(80H + c DIV 64 MOD 64); PuneOctet(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0E000H) THEN PuneOctet(ORD("?"))
      ELSE PuneOctet(0E0H + c DIV 1000H); PuneOctet(80H + c DIV 64 MOD 64); PuneOctet(80H + c MOD 64)
      END
    END ;
    PuneOctet(0AH);
    E7Txt.Pune(sTo, ns, T - 1); E7Txt.Pune(sRec, ns, rec); E7Txt.Pune(sLa, ns, nul);
    (* cuvintele cu sens -> formele de baza, fara dubluri *)
    n0 := 0; w := 0;
    FOR i := a TO b DO
      IF i < b THEN ch := E7Txt.C(buf, i); IF ch = 0AX THEN ch := " " END ; ch := E7Txt.Mic(ch) ELSE ch := " " END ;
      IF ch = CHR(15FH) THEN ch := CHR(219H) ELSIF ch = CHR(163H) THEN ch := CHR(21BH) END ;
      IF E7Txt.LitCif(ch) THEN
        IF w < MaxW - 1 THEN cuv[w] := ch END ;
        INC(w)
      ELSIF w > 0 THEN
        IF w < MaxW THEN cuv[w] := 0X ELSE cuv[MaxW - 1] := 0X END ;
        w := 0;
        IF E7Txt.Litera(cuv[0]) & Continut(cuv) THEN
          E7Gram.Baza(cuv, baza); id := IdOf(baza);
          k := 0; da := TRUE;
          WHILE da & (k < n0) DO IF idsF[k] = id THEN da := FALSE END ; INC(k) END ;
          IF da & (n0 < LEN(idsF)) THEN idsF[n0] := id; INC(n0) END
        END
      END
    END ;
    FOR k := 0 TO n0 - 1 DO E7Txt.Pune(ul, nul, idsF[k]); INC(nul); Posteaza(idsF[k], ns) END ;
    E7Txt.Pune(sLn, ns, n0);
    INC(ns)
  END AdaugaFraza;

  PROCEDURE Lungime*(s: INTEGER): INTEGER;      (* in octeti UTF-8, ca in Eula 7 *)
  BEGIN RETURN E7Txt.Ia(sTo, s) - E7Txt.Ia(sFrom, s)
  END Lungime;

  PROCEDURE Rec*(s: INTEGER): INTEGER;
  BEGIN RETURN E7Txt.Ia(sRec, s)
  END Rec;

  PROCEDURE NLeme*(s: INTEGER): INTEGER;
  BEGIN RETURN E7Txt.Ia(sLn, s)
  END NLeme;

  PROCEDURE LemaF*(s, k: INTEGER): INTEGER;     (* forma de baza k a frazei s *)
  BEGIN RETURN E7Txt.Ia(ul, E7Txt.Ia(sLa, s) + k)
  END LemaF;

  PROCEDURE Are*(s, id: INTEGER): BOOLEAN;
    VAR a, n, k: INTEGER; da: BOOLEAN;
  BEGIN a := E7Txt.Ia(sLa, s); n := E7Txt.Ia(sLn, s); k := 0; da := FALSE;
    WHILE ~da & (k < n) DO da := E7Txt.Ia(ul, a + k) = id; INC(k) END ;
    RETURN da
  END Are;

  (* textul frazei s (UTF-8 -> semne) *)
  PROCEDURE Fraza*(s: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i, e, j, b, c: INTEGER;
  BEGIN i := E7Txt.Ia(sFrom, s); e := E7Txt.Ia(sTo, s); j := 0;
    WHILE (i < e) & (j < LEN(d) - 2) DO
      b := Octet(i); INC(i);
      IF b < 80H THEN c := b
      ELSIF b < 0E0H THEN c := (b MOD 32) * 64 + Octet(i) MOD 64; INC(i)
      ELSIF b < 0F0H THEN c := (b MOD 16) * 1000H + (Octet(i) MOD 64) * 64 + Octet(i+1) MOD 64; i := i + 2
      ELSE
        c := (b MOD 8) * 40000H + (Octet(i) MOD 64) * 1000H + (Octet(i+1) MOD 64) * 64 + Octet(i+2) MOD 64; i := i + 3;
        c := c - 10000H; d[j] := CHR(0D800H + c DIV 400H); INC(j); c := 0DC00H + c MOD 400H
      END ;
      d[j] := CHR(c); INC(j)
    END ;
    d[j] := 0X
  END Fraza;

  PROCEDURE RecSursa*(r: INTEGER; VAR d: ARRAY OF CHAR);
    VAR a, n, i: INTEGER;
  BEGIN a := E7Txt.Ia(recA, r); n := E7Txt.Ia(recN, r); i := 0;
    WHILE (i < n) & (i < LEN(d) - 1) DO d[i] := E7Txt.C(srcPool, a + i); INC(i) END ;
    d[i] := 0X
  END RecSursa;

  PROCEDURE Sursa*(s: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN RecSursa(E7Txt.Ia(sRec, s), d)
  END Sursa;

  (* ---------- curatarea: HTML, legaturi, semne de formatare (ca expresiile din Eula 7) ---------- *)

  PROCEDURE La(x: E7Txt.Chars; n, i: INTEGER; p: ARRAY OF CHAR): BOOLEAN;
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (p[j] # 0X) & (i + j < n) & (E7Txt.C(x, i + j) = p[j]) DO INC(j) END ;
    RETURN p[j] = 0X
  END La;

  PROCEDURE Gaseste(x: E7Txt.Chars; n, i: INTEGER; p: ARRAY OF CHAR): INTEGER;
    VAR r: INTEGER;
  BEGIN r := -1;
    WHILE (r < 0) & (i < n) DO IF La(x, n, i, p) THEN r := i END ; INC(i) END ;
    RETURN r
  END Gaseste;

  (* o trecere: din x[a..n) in y; intoarce cat a scris *)
  PROCEDURE Trece(pas: INTEGER; x: E7Txt.Chars; a, n: INTEGER; y: E7Txt.Chars): INTEGER;
    VAR i, j, k, d, m: INTEGER; c: CHAR; faraScript, faraStyle, gata: BOOLEAN;
  BEGIN i := a; m := 0; faraScript := FALSE; faraStyle := FALSE;
    WHILE i < n DO
      c := E7Txt.C(x, i); gata := FALSE;
      IF pas = 1 THEN                    (* (?s)<script.*?</script>|<style.*?</style> -> " " *)
        IF c = "<" THEN
          IF ~faraScript & La(x, n, i, "<script") THEN
            j := Gaseste(x, n, i + 7, "</script>");
            IF j >= 0 THEN E7Txt.PuneC(y, m, " "); INC(m); i := j + 9; gata := TRUE ELSE faraScript := TRUE END
          ELSIF ~faraStyle & La(x, n, i, "<style") THEN
            j := Gaseste(x, n, i + 6, "</style>");
            IF j >= 0 THEN E7Txt.PuneC(y, m, " "); INC(m); i := j + 8; gata := TRUE ELSE faraStyle := TRUE END
          END
        END
      ELSIF pas = 2 THEN                 (* <[^>]{0,300}> -> " " *)
        IF c = "<" THEN
          j := i + 1;
          WHILE (j < n) & (j - i - 1 <= 300) & (E7Txt.C(x, j) # ">") DO INC(j) END ;
          IF (j < n) & (j - i - 1 <= 300) THEN E7Txt.PuneC(y, m, " "); INC(m); i := j + 1; gata := TRUE END
        END
      ELSIF pas = 3 THEN                 (* https?://\S+ -> " " *)
        IF (c = "h") & La(x, n, i, "http") THEN
          k := i + 4;
          IF (k < n) & (E7Txt.C(x, k) = "s") & La(x, n, k + 1, "://") THEN k := k + 4
          ELSIF La(x, n, k, "://") THEN k := k + 3
          ELSE k := -1
          END ;
          IF (k > 0) & (k < n) & ~E7Txt.Spatiu(E7Txt.C(x, k)) THEN
            WHILE (k < n) & ~E7Txt.Spatiu(E7Txt.C(x, k)) DO INC(k) END ;
            E7Txt.PuneC(y, m, " "); INC(m); i := k; gata := TRUE
          END
        END
      ELSIF pas = 4 THEN                 (* [*#_`|>]+ -> " " *)
        IF (c = "*") OR (c = "#") OR (c = "_") OR (c = "`") OR (c = "|") OR (c = ">") THEN
          REPEAT INC(i); IF i < n THEN c := E7Txt.C(x, i) END
          UNTIL (i >= n) OR ~((c = "*") OR (c = "#") OR (c = "_") OR (c = "`") OR (c = "|") OR (c = ">"));
          E7Txt.PuneC(y, m, " "); INC(m); gata := TRUE
        END
      ELSIF pas = 5 THEN                 (* \[[0-9]{1,3}\] -> "" *)
        IF c = "[" THEN
          d := 0;
          WHILE (i + 1 + d < n) & (E7Txt.C(x, i + 1 + d) >= "0") & (E7Txt.C(x, i + 1 + d) <= "9") DO INC(d) END ;
          IF (d >= 1) & (d <= 3) & (i + 1 + d < n) & (E7Txt.C(x, i + 1 + d) = "]") THEN i := i + d + 2; gata := TRUE END
        END
      ELSE                               (* [ \t\x0B\f\r]+ -> " " *)
        IF (c = " ") OR (c = 9X) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX) THEN
          REPEAT INC(i); IF i < n THEN c := E7Txt.C(x, i) END
          UNTIL (i >= n) OR ~((c = " ") OR (c = 9X) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX));
          E7Txt.PuneC(y, m, " "); INC(m); gata := TRUE
        END
      END ;
      IF ~gata THEN E7Txt.PuneC(y, m, c); INC(m); INC(i) END
    END ;
    RETURN m
  END Trece;

  PROCEDURE InceputFraza(c: CHAR): BOOLEAN;        (* [\p{Lu}0-9„"(] *)
  BEGIN RETURN E7Txt.Lu(c) OR (c >= "0") & (c <= "9") OR (c = CHR(201EH)) OR (c = 22X) OR (c = "(")
  END InceputFraza;

  (* bucata [a, b) din x: \n -> spatiu, fara capete <= " "; daca are macar 3 semne, intra *)
  PROCEDURE Bucata(x: E7Txt.Chars; a, b, rec: INTEGER; VAR k: INTEGER);
  BEGIN
    WHILE (a < b) & (E7Txt.C(x, a) <= " ") DO INC(a) END ;
    WHILE (b > a) & (E7Txt.C(x, b - 1) <= " ") DO DEC(b) END ;
    IF b - a >= 3 THEN AdaugaFraza(x, a, b, rec); INC(k) END
  END Bucata;

  (* adauga o bucata de text (o masa): corp[de..corpN); intoarce cate fraze noi *)
  PROCEDURE Adauga*(de: INTEGER; src: ARRAY OF CHAR): INTEGER;
    VAR rec, n, i, p, e, u, start, k: INTEGER; x, y, t: E7Txt.Chars; c: CHAR; gasit: BOOLEAN;
  BEGIN
    rec := nrec; INC(nrec);
    E7Txt.Pune(recA, rec, nsrc); i := 0;
    WHILE (i < LEN(src)) & (src[i] # 0X) DO E7Txt.PuneC(srcPool, nsrc, src[i]); INC(nsrc); INC(i) END ;
    E7Txt.Pune(recN, rec, i);
    x := corp; y := aux;
    n := Trece(1, x, de, corpN, y); t := x; x := y; y := t;
    n := Trece(2, x, 0, n, y); t := x; x := y; y := t;
    n := Trece(3, x, 0, n, y); t := x; x := y; y := t;
    n := Trece(4, x, 0, n, y); t := x; x := y; y := t;
    n := Trece(5, x, 0, n, y); t := x; x := y; y := t;
    n := Trece(6, x, 0, n, y);
    x := y;
    (* fraza se termina: (?<=[.!?…])\s+(?=[\p{Lu}0-9„"(]) | \n\s*\n | \n(?=[-•\p{Lu}]) *)
    k := 0; start := 0; p := 0;
    WHILE p < n DO
      c := E7Txt.C(x, p); gasit := FALSE; e := p;
      IF (p > 0) & E7Txt.Spatiu(c) THEN
        u := ORD(E7Txt.C(x, p - 1));
        IF (u = ORD(".")) OR (u = ORD("!")) OR (u = ORD("?")) OR (u = 2026H) THEN
          e := p; WHILE (e < n) & E7Txt.Spatiu(E7Txt.C(x, e)) DO INC(e) END ;
          IF (e < n) & InceputFraza(E7Txt.C(x, e)) THEN gasit := TRUE END
        END
      END ;
      IF ~gasit & (c = 0AX) THEN
        e := p + 1; u := -1;
        WHILE (e < n) & E7Txt.Spatiu(E7Txt.C(x, e)) DO IF E7Txt.C(x, e) = 0AX THEN u := e END ; INC(e) END ;
        IF u >= 0 THEN e := u + 1; gasit := TRUE
        ELSIF (p + 1 < n) & ((E7Txt.C(x, p + 1) = "-") OR (E7Txt.C(x, p + 1) = CHR(2022H)) OR E7Txt.Lu(E7Txt.C(x, p + 1))) THEN
          e := p + 1; gasit := TRUE
        END
      END ;
      IF gasit THEN Bucata(x, start, p, rec, k); start := e; p := e ELSE INC(p) END
    END ;
    Bucata(x, start, n, rec, k);
    RETURN k
  END Adauga;

  PROCEDURE ArataCu*(p: Arata);      (* cine arata cat a citit (sau NIL) *)
  BEGIN arata := p
  END ArataCu;

  PROCEDURE CorpTaie*(n: INTEGER);    (* pastreaza doar primele n semne *)
  BEGIN IF (n >= 0) & (n < corpN) THEN corpN := n END
  END CorpTaie;

  PROCEDURE CorpGol*;
  BEGIN corpN := 0
  END CorpGol;

  PROCEDURE CorpC*(c: CHAR);
  BEGIN E7Txt.PuneC(corp, corpN, c); INC(corpN)
  END CorpC;

  PROCEDURE CorpS*(s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO CorpC(s[i]); INC(i) END
  END CorpS;

  (* ---------- pornirea: memoria din fisier, golirea ---------- *)

  PROCEDURE Goleste*;
    VAR i: INTEGER;
  BEGIN
    FOR i := 0 TO NB - 1 DO txt[i] := NIL END ;
    T := 0; ns := 0; nul := 0; nrec := 0; nsrc := 0; npost := 0;
    sFrom := E7Txt.NouInts(); sTo := E7Txt.NouInts(); sRec := E7Txt.NouInts(); sLa := E7Txt.NouInts(); sLn := E7Txt.NouInts();
    ul := E7Txt.NouInts(); recA := E7Txt.NouInts(); recN := E7Txt.NouInts(); srcPool := E7Txt.NouChars();
    lems := E7Txt.NouTabel(); fd := E7Txt.NouTabel();
    pHead := E7Txt.NouInts(); pTail := E7Txt.NouInts(); pCnt := E7Txt.NouInts(); pS := E7Txt.NouInts(); pNext := E7Txt.NouInts()
  END Goleste;

  (* bucata i (de la start): fara antet daca e prima; altfel antetul e „timp<TAB>sursa” *)
  PROCEDURE Masa(i: INTEGER; VAR k: INTEGER);
    VAR nl, tab, j: INTEGER; gol: BOOLEAN;
  BEGIN
    fx := "memoria veche"; nl := 0;
    IF i > 0 THEN
      WHILE (nl < corpN) & (E7Txt.C(corp, nl) # 0AX) DO INC(nl) END ;
      tab := 0;
      WHILE (tab < nl) & (E7Txt.C(corp, tab) # 9X) DO INC(tab) END ;
      IF tab < nl THEN
        j := 0;
        WHILE (tab + 1 + j < nl) & (j < LEN(fx) - 1) DO fx[j] := E7Txt.C(corp, tab + 1 + j); INC(j) END ;
        fx[j] := 0X
      END ;
      IF nl < corpN THEN INC(nl) END
    END ;
    gol := TRUE; j := nl;
    WHILE gol & (j < corpN) DO IF E7Txt.C(corp, j) > " " THEN gol := FALSE END ; INC(j) END ;
    IF ~gol THEN j := Adauga(nl, fx); INC(k) END
  END Masa;

  (* citeste fisierul memoriei de la octetul start; bucatile sunt despartite de „\n␞”. Intoarce cate bucati *)
  PROCEDURE Citeste*(cale: ARRAY OF CHAR; start: INTEGER): INTEGER;
    VAR b, c, i, k, tot, pct, ultim, x: INTEGER; nl: BOOLEAN;

    PROCEDURE Urm(): INTEGER;
      VAR r: INTEGER;
    BEGIN
      IF inapoi >= 0 THEN r := inapoi; inapoi := -1 ELSE r := E7Disc.Octet() END ;
      RETURN r
    END Urm;

  BEGIN k := 0;
    IF E7Disc.Citeste(cale) THEN
      tot := E7Disc.Marime(); E7Disc.Sari(start);
      i := 0; corpN := 0; nl := FALSE; inapoi := -1; ultim := -1;
      b := E7Disc.Octet();
      WHILE b >= 0 DO
        IF nl THEN
          nl := FALSE;
          IF b = 1EH THEN Masa(i, k); INC(i); corpN := 0; b := -2
          ELSE CorpC(0AX)
          END
        END ;
        IF b = -2 THEN (* separatorul a fost consumat *)
        ELSIF b = 0AH THEN nl := TRUE
        ELSIF b < 80H THEN CorpC(CHR(b))
        ELSE                                  (* UTF-8 *)
          IF (b >= 0C2H) & (b < 0E0H) THEN c := b MOD 32; x := 1
          ELSIF (b >= 0E0H) & (b < 0F0H) THEN c := b MOD 16; x := 2
          ELSIF (b >= 0F0H) & (b < 0F5H) THEN c := b MOD 8; x := 3
          ELSE c := -1; x := 0
          END ;
          IF c < 0 THEN CorpC(CHR(0FFFDH))
          ELSE
            WHILE x > 0 DO
              b := E7Disc.Octet();
              IF (b >= 80H) & (b < 0C0H) THEN c := c * 64 + b MOD 64; DEC(x)
              ELSE x := -x; inapoi := b
              END
            END ;
            IF x < 0 THEN CorpC(CHR(0FFFDH))
            ELSIF c >= 10000H THEN c := c - 10000H; CorpC(CHR(0D800H + c DIV 400H)); CorpC(CHR(0DC00H + c MOD 400H))
            ELSE CorpC(CHR(c))
            END
          END
        END ;
        IF (arata # NIL) & (tot > 0) THEN
          pct := (E7Disc.citit DIV 1024) * 100 DIV (tot DIV 1024 + 1);
          IF pct # ultim THEN ultim := pct; arata(pct) END
        END ;
        b := Urm()
      END ;
      IF nl THEN CorpC(0AX) END ;
      Masa(i, k);
      E7Disc.InchideC
    END ;
    RETURN k
  END Citeste;

  (* ---------- fotografia: memoria gata indexata, pentru pornirea rapida ---------- *)

  PROCEDURE Salveaza*(cale: ARRAY OF CHAR; acoperit: INTEGER): BOOLEAN;
    VAR tmp: ARRAY 1100 OF CHAR; i, s, k, n, a, r: INTEGER; ok: BOOLEAN;
  BEGIN E7Txt.Copy(cale, tmp); E7Txt.Add(tmp, ".tmp");
    ok := E7Disc.Scrie(tmp);
    IF ok THEN
      E7Disc.PuneInt(MAGIC); E7Disc.PuneInt(VER); E7Disc.PuneInt(acoperit);
      E7Disc.PuneInt(T); i := 0;
      WHILE i < T DO
        n := T - i; IF n > B THEN n := B END ;
        E7Disc.PuneOcteti(txt[i DIV B].a, n); i := i + n
      END ;
      E7Disc.PuneInt(nrec);
      FOR r := 0 TO nrec - 1 DO
        a := E7Txt.Ia(recA, r); n := E7Txt.Ia(recN, r); IF n > 2000 THEN n := 2000 END ;
        E7Disc.PuneInt(n);
        FOR k := 0 TO n - 1 DO E7Disc.PuneCh(E7Txt.C(srcPool, a + k)) END
      END ;
      E7Disc.PuneInt(lems.n);
      FOR i := 0 TO lems.n - 1 DO
        n := E7Txt.Lung(lems, i); E7Disc.PuneInt(n);
        FOR k := 0 TO n - 1 DO E7Disc.PuneCh(E7Txt.SirC(lems, i, k)) END
      END ;
      E7Disc.PuneInt(ns);
      FOR s := 0 TO ns - 1 DO
        E7Disc.PuneInt(E7Txt.Ia(sFrom, s)); E7Disc.PuneInt(E7Txt.Ia(sTo, s)); E7Disc.PuneInt(E7Txt.Ia(sRec, s));
        n := E7Txt.Ia(sLn, s); a := E7Txt.Ia(sLa, s); E7Disc.PuneInt(n);
        FOR k := 0 TO n - 1 DO E7Disc.PuneInt(E7Txt.Ia(ul, a + k)) END
      END ;
      E7Disc.Inchide; ok := E7Disc.sok;
      IF ok THEN ok := E7Disc.Redenumeste(tmp, cale) END
    END ;
    RETURN ok
  END Salveaza;

  (* intoarce cati octeti din fisierul memoriei acopera fotografia, sau -1 *)
  PROCEDURE Incarca*(cale: ARRAY OF CHAR): INTEGER;
    VAR cov, i, n, k, r, s, a, id: INTEGER; ok: BOOLEAN;
  BEGIN cov := -1; Goleste;
    IF E7Disc.Citeste(cale) THEN
      IF (E7Disc.Int() = MAGIC) & (E7Disc.Int() = VER) THEN
        cov := E7Disc.Int();
        n := E7Disc.Int(); i := 0;
        WHILE E7Disc.ok & (i < n) DO
          k := n - i; IF k > B THEN k := B END ;
          IF txt[i DIV B] = NIL THEN NEW(txt[i DIV B]) END ;
          k := E7Disc.Octeti(txt[i DIV B].a, k); i := i + k;
          IF k = 0 THEN i := n + 1 END
        END ;
        ok := i = n; T := n;
        nrec := E7Disc.Int();
        FOR r := 0 TO nrec - 1 DO
          n := E7Disc.Int(); E7Txt.Pune(recA, r, nsrc); E7Txt.Pune(recN, r, n);
          FOR k := 0 TO n - 1 DO E7Txt.PuneC(srcPool, nsrc, E7Disc.Ch()); INC(nsrc) END
        END ;
        n := E7Disc.Int();
        FOR i := 0 TO n - 1 DO
          k := E7Disc.Int(); IF k > MaxW - 1 THEN ok := FALSE; k := 0 END ;
          FOR a := 0 TO k - 1 DO baza[a] := E7Disc.Ch() END ;
          baza[k] := 0X; id := IdOf(baza)
        END ;
        ns := E7Disc.Int();
        FOR s := 0 TO ns - 1 DO
          E7Txt.Pune(sFrom, s, E7Disc.Int()); E7Txt.Pune(sTo, s, E7Disc.Int()); E7Txt.Pune(sRec, s, E7Disc.Int());
          k := E7Disc.Int(); E7Txt.Pune(sLa, s, nul); E7Txt.Pune(sLn, s, k);
          FOR a := 0 TO k - 1 DO id := E7Disc.Int(); E7Txt.Pune(ul, nul, id); INC(nul); Posteaza(id, s) END
        END ;
        IF ~ok OR ~E7Disc.ok THEN cov := -1; Goleste END
      END ;
      E7Disc.InchideC
    END ;
    RETURN cov
  END Incarca;

BEGIN
  stop := E7Txt.NouTabel(); cerere := E7Txt.NouTabel();
    E7Txt.Lista(stop, "și si sau dar iar în in la pe cu de din pentru prin spre către catre despre după dupa până pana fără fara sub peste între intre printre lângă langa un o unui unei niște niste cel cea cei cele celui");
    E7Txt.Lista(stop, "celei celor al a ai ale lui ei lor el ea ele eu tu noi voi se să sa ca că ce care cine cum când cand unde cât cat câți cati câte cate este e sunt era erau au am are aveau avea fost fi fie nu mai");
    E7Txt.Lista(stop, "foarte acest această aceasta acesta aceste acești acesti acel acea aceea acela aceia acele asta ăsta asa așa tot toate toți toti totul doar chiar încă inca deja însă insa deci dacă daca ori ne vă va");
    E7Txt.Lista(stop, "le îl il îi ii își isi mi ți ti nici decât decat etc ceea cele ceva cineva fiecare orice alte alt alta altă alți alti său sau sa sale săi sai lor mea meu mei mele ta tău tau noastră nostru vostru");
    E7Txt.Lista(stop, "voastră dintre asupra conform potrivit atunci acolo aici acum apoi astfel unii unele unor multe mult mulți multi puțin putin poate pot putea trebuie vor va vom veți ar aș as ați ati am ești esti");
    E7Txt.Lista(stop, "suntem sunteți sunteti eram erai fusese fiind avut avand având");
    E7Txt.Lista(cerere, "descrie descrieti descrii descriu explica explicati explici explicami spune spuneti spui spunemi povesteste povestiti povestestemi povestesti zi zimi ziceti arata aratami aratati arati poti puteti");
    E7Txt.Lista(cerere, "poate stii stiti cunosti cunoasteti vreau vrei vrem doresc rog despre ceva putin scurt pe scurt detaliat detalii informatii lamureste lamuriti defineste definiti prezinta prezentati enumera enumerati");
    E7Txt.Lista(cerere, "da dami dati");
  corp := E7Txt.NouChars(); aux := E7Txt.NouChars(); corpN := 0; arata := NIL;
  Goleste
END E7Mem.


MODULE E7Sor; (* Eula 7 in Oberon: sorobanul in a 7-a dimensiune (ideea lui Pion, din Soroban7).
  Torul Z7^7 (7^7 = 823.543 de cuburi), fiecare centru porneste de la 5 (piatra soarelui). Baza 7 fara zero:
  B7(n) = ((n-1) mod 7) + 1. Un colt e comun pentru 2^7 = 128 de cuburi, deci un impuls pleaca pe 128 de raze
  diagonale, o tura (7 cuburi) fiecare: centru = B7(centru + impuls + 2), iar valoarea noua merge mai departe.
  Un cuvant (forma lui de baza) intra prin coltul dat de primele lui 7 litere, cate una pe fiecare axa
  (litera lipsa = 5); impulsurile sunt literele, pe rand. Valoarea unei litere = B7(locul ei in alfabetul de 31).
  Geometria se poate schimba din conversatie: spirala, razele prin fete, regula cuburilor N7, 49 de litere. *)

  IMPORT E7Txt;

  CONST D = 7; N = 823543; M = 823542;

  TYPE Stare* = POINTER TO StareDesc;
    StareDesc* = RECORD
      v: ARRAY N OF BYTE;
      mark: ARRAY N OF BOOLEAN;
      at: ARRAY N OF INTEGER;
      n: INTEGER
    END ;

  VAR
    spirala*, fete*, litere49*: BOOLEAN;   (* geometria: tor/spirala, raze prin fete, 49 de litere *)
    n7*: CHAR;                              (* regula cuburilor N7: "Z" ca Z7, "A" scade, "C" oglinda *)
    P7: ARRAY D OF INTEGER;
    alfabet: ARRAY 40 OF CHAR;

  PROCEDURE B7(n: INTEGER): INTEGER;
  BEGIN RETURN (n - 1) MOD 7 + 1
  END B7;

  PROCEDURE Val*(c: CHAR): INTEGER;
    VAR p, r: INTEGER;
  BEGIN p := 0;
    WHILE (alfabet[p] # 0X) & (alfabet[p] # c) DO INC(p) END ;
    IF alfabet[p] # 0X THEN r := B7(p + 1)
    ELSIF (c >= "0") & (c <= "9") THEN r := B7(ORD(c) - ORD("0") + 1)
    ELSE r := -1
    END ;
    RETURN r
  END Val;

  PROCEDURE Nou*(): Stare;
    VAR s: Stare; i: INTEGER;
  BEGIN NEW(s); s.n := 0;
    FOR i := 0 TO N - 1 DO s.v[i] := 5; s.mark[i] := FALSE END ;
    RETURN s
  END Nou;

  PROCEDURE Goleste*(s: Stare);
    VAR k: INTEGER;
  BEGIN
    FOR k := 0 TO s.n - 1 DO s.v[s.at[k]] := 5; s.mark[s.at[k]] := FALSE END ;
    s.n := 0
  END Goleste;

  PROCEDURE Aprinse*(s: Stare): INTEGER;
    VAR k, r: INTEGER;
  BEGIN r := 0;
    FOR k := 0 TO s.n - 1 DO IF s.v[s.at[k]] # 5 THEN INC(r) END END ;
    RETURN r
  END Aprinse;

  PROCEDURE Descriere*(VAR d: ARRAY OF CHAR);
  BEGIN d := "geometrie: ";
    IF spirala THEN E7Txt.Add(d, "spirală") ELSE E7Txt.Add(d, "tor") END ;
    E7Txt.Add(d, " · raze: ");
    IF fete THEN E7Txt.Add(d, "diagonale + fețe") ELSE E7Txt.Add(d, "diagonale") END ;
    E7Txt.Add(d, " · N7: ");
    IF n7 = "Z" THEN E7Txt.Add(d, "ca Z7") ELSIF n7 = "A" THEN E7Txt.Add(d, "scade") ELSE E7Txt.Add(d, "oglindă (8−d)") END ;
    E7Txt.Add(d, " · litere: ");
    IF litere49 THEN E7Txt.Add(d, "49, fără diacritice") ELSE E7Txt.Add(d, "7") END
  END Descriere;

  PROCEDURE Seteaza*(sp, fe, l49: BOOLEAN; n: CHAR);   (* geometria, din conversatie sau din butoane *)
  BEGIN spirala := sp; fete := fe; litere49 := l49;
    IF (n = "Z") OR (n = "A") OR (n = "C") THEN n7 := n END
  END Seteaza;

  PROCEDURE Regula(v, w: INTEGER; n: BOOLEAN): INTEGER;
    VAR r: INTEGER;
  BEGIN
    IF ~n OR (n7 = "Z") THEN r := B7(v + w + 2)
    ELSIF n7 = "A" THEN r := B7(v - w - 2)
    ELSE r := 8 - B7(v + w + 2)
    END ;
    RETURN r
  END Regula;

  PROCEDURE Impuls(s: Stare; VAR colt: ARRAY OF INTEGER; val: INTEGER);
    VAR c: ARRAY D OF INTEGER; r, raze, dir, axa, semn, k, w, step, i, par, x, t, d, nv: INTEGER;
  BEGIN
    IF fete THEN raze := 142 ELSE raze := 128 END ;
    FOR r := 0 TO raze - 1 DO
      dir := 0; axa := -1; semn := 1;
      IF r < 128 THEN dir := r ELSE axa := (r - 128) DIV 2; IF ODD(r - 128) THEN semn := -1 END END ;
      FOR k := 0 TO D - 1 DO
        IF (axa < 0) & ODD(ASR(dir, k)) THEN c[k] := colt[k] + 6 ELSE c[k] := colt[k] END
      END ;
      w := val;
      FOR step := 0 TO 6 DO
        par := 0;
        IF ~spirala THEN
          i := 0;
          FOR k := 0 TO D - 1 DO i := i + (c[k] MOD 7) * P7[k]; par := par + c[k] MOD 7 END
        ELSE
          x := 0;
          FOR k := 0 TO D - 1 DO x := x + c[k] * P7[k] END ;
          i := x MOD M; t := i;
          FOR k := 0 TO D - 1 DO par := par + t MOD 7; t := t DIV 7 END
        END ;
        IF ~s.mark[i] THEN s.mark[i] := TRUE; s.at[s.n] := i; INC(s.n) END ;
        nv := Regula(s.v[i], w, ODD(par));
        s.v[i] := nv; w := nv;
        FOR k := 0 TO D - 1 DO
          IF axa >= 0 THEN IF k = axa THEN d := semn ELSE d := 0 END
          ELSIF ODD(ASR(dir, k)) THEN d := -1
          ELSE d := 1
          END ;
          IF spirala THEN c[k] := c[k] + d
          ELSIF d < 0 THEN c[k] := c[k] + 6
          ELSE c[k] := c[k] + d
          END
        END
      END
    END
  END Impuls;

  PROCEDURE Cuvant*(s: Stare; cuv: ARRAY OF CHAR);
    VAR v: ARRAY 49 OF INTEGER; colt: ARRAY D OF INTEGER; max, n, i, k: INTEGER; c: CHAR;
  BEGIN
    IF litere49 THEN max := 49 ELSE max := 7 END ;
    n := 0; i := 0;
    WHILE (i < LEN(cuv)) & (cuv[i] # 0X) & (n < max) DO
      c := cuv[i];
      IF litere49 THEN
        IF (c = CHR(103H)) OR (c = CHR(0E2H)) THEN c := "a"
        ELSIF c = CHR(0EEH) THEN c := "i"
        ELSIF (c = CHR(219H)) OR (c = CHR(15FH)) THEN c := "s"
        ELSIF (c = CHR(21BH)) OR (c = CHR(163H)) THEN c := "t"
        END
      END ;
      k := Val(c); IF k > 0 THEN v[n] := k; INC(n) END ;
      INC(i)
    END ;
    IF n >= 3 THEN
      FOR k := 0 TO D - 1 DO IF k < n THEN colt[k] := v[k] - 1 ELSE colt[k] := 4 END END ;
      FOR i := 0 TO n - 1 DO Impuls(s, colt, v[i]) END
    END
  END Cuvant;

  (* pe centrele aprinse de intrebare: +1 daca si fraza l-a aprins, +1 daca are aceeasi valoare *)
  PROCEDURE Scor*(q, f: Stare): INTEGER;
    VAR k, i, r: INTEGER;
  BEGIN r := 0;
    FOR k := 0 TO q.n - 1 DO
      i := q.at[k];
      IF q.v[i] # 5 THEN
        IF f.v[i] # 5 THEN INC(r) END ;
        IF f.v[i] = q.v[i] THEN INC(r) END
      END
    END ;
    RETURN r
  END Scor;

BEGIN
  P7[0] := 1; P7[1] := 7; P7[2] := 49; P7[3] := 343; P7[4] := 2401; P7[5] := 16807; P7[6] := 117649;
  alfabet := "aăâbcdefghiîjklmnopqrsștțuvwxyz";
  spirala := FALSE; fete := FALSE; litere49 := FALSE; n7 := "Z"
END E7Sor.


MODULE E7Roler; (* Eula 7 in Oberon: Roler peste Cubicum FS (ideea lui Pion). Fiecare fisier (bucata mancata)
  primeste un nod (x, y, z) din Z7^3 si frecventa nodului, f = 256 * (3/2)^x * 2^y * (7/4)^z. Cvinta (x) = domeniul,
  pe cercul cvintelor; octava (y) = marimea (de doua ori mai mare = o octava mai sus); septima naturala (z) = sursa,
  timbrul. Frecventa se socoteste exact, cu numere intregi: f = 3^x * 7^z * 2^(8 + y - x - 2z). *)

  IMPORT E7Txt, E7Mem;

  VAR domeniu, sursaN: ARRAY 7 OF ARRAY 40 OF CHAR;
    chei: ARRAY 7 OF ARRAY 20 OF ARRAY 16 OF CHAR;
    domL: E7Txt.Ints; nlDom: INTEGER;            (* domeniul fiecarei forme de baza (-1 = niciunul), +1 *)
    nodX*, nodY*, nodZ*, mar, cnt: E7Txt.Ints; R: INTEGER;
    calculatLa: INTEGER;
    src: ARRAY 4096 OF CHAR;

  PROCEDURE Chei(d: INTEGER; s: ARRAY OF CHAR);
    VAR i, j, k: INTEGER;
  BEGIN i := 0; k := 0;
    WHILE s[i] # 0X DO
      j := 0;
      WHILE (s[i] # 0X) & (s[i] # " ") DO chei[d][k][j] := s[i]; INC(i); INC(j) END ;
      chei[d][k][j] := 0X; INC(k);
      IF s[i] = " " THEN INC(i) END
    END
  END Chei;

  PROCEDURE Marime(octeti: INTEGER): INTEGER;
    VAR y: INTEGER;
  BEGIN y := 0;
    WHILE (y < 6) & (1024 * LSL(1, y + 1) <= octeti) DO INC(y) END ;
    RETURN y
  END Marime;

  PROCEDURE Sursa(r: INTEGER): INTEGER;
    VAR z: INTEGER;
  BEGIN E7Mem.RecSursa(r, src); E7Txt.MicS(src);
    IF E7Txt.Contine(src, "memoria veche") OR E7Txt.Contine(src, "memoria eulei") THEN z := 6
    ELSIF E7Txt.Contine(src, "zenodo") OR E7Txt.Contine(src, "github") OR E7Txt.Contine(src, "pion") OR E7Txt.Contine(src, "jahbalon")
      OR E7Txt.Contine(src, "nota eula") OR E7Txt.Contine(src, "conversa") OR E7Txt.Contine(src, "învățat") OR E7Txt.Contine(src, "invatat") THEN z := 0
    ELSIF E7Txt.Contine(src, "dglr") OR E7Txt.Contine(src, "dtlr") OR E7Txt.Contine(src, "literatura") THEN z := 2
    ELSIF E7Txt.Contine(src, "jrc") OR E7Txt.Contine(src, "acquis") THEN z := 3
    ELSIF E7Txt.Contine(src, "simonero") THEN z := 4
    ELSIF E7Txt.Contine(src, "wikipedia") OR E7Txt.Contine(src, "wiki") THEN z := 1
    ELSE z := 5
    END ;
    RETURN z
  END Sursa;

  PROCEDURE Putere(b, e: INTEGER): INTEGER;
    VAR r: INTEGER;
  BEGIN r := 1; WHILE e > 0 DO r := r * b; DEC(e) END ;
    RETURN r
  END Putere;

  PROCEDURE Frec*(x, y, z: INTEGER): REAL;
    VAR n, e: INTEGER; f: REAL;
  BEGIN n := Putere(3, x) * Putere(7, z); e := 8 + y - x - 2 * z; f := FLT(n);
    WHILE e > 0 DO f := f * 2.0; DEC(e) END ;
    WHILE e < 0 DO f := f / 2.0; INC(e) END ;
    RETURN f
  END Frec;

  (* frecventa nodului, rotunjita (jumatatea in sus), cu punct la mii: „%,.0f” *)
  PROCEDURE FrecIn(x, y, z: INTEGER; VAR d: ARRAY OF CHAR);
    VAR c: ARRAY 24 OF INTEGER; n, e, i, k, t: INTEGER;
  BEGIN n := Putere(3, x) * Putere(7, z); e := 8 + y - x - 2 * z;
    IF e < 0 THEN n := (n + LSL(1, -e - 1)) DIV LSL(1, -e); e := 0 END ;
    k := 0; REPEAT c[k] := n MOD 10; n := n DIV 10; INC(k) UNTIL n = 0;
    WHILE e > 0 DO                       (* * 2, cifra cu cifra *)
      t := 0;
      FOR i := 0 TO k - 1 DO t := c[i] * 2 + t; c[i] := t MOD 10; t := t DIV 10 END ;
      IF t > 0 THEN c[k] := t; INC(k) END ;
      DEC(e)
    END ;
    WHILE k > 0 DO
      DEC(k); E7Txt.AddCh(d, CHR(ORD("0") + c[k]));
      IF (k > 0) & (k MOD 3 = 0) THEN E7Txt.AddCh(d, ".") END
    END
  END FrecIn;

  PROCEDURE D(a, b: INTEGER): INTEGER;
    VAR v: INTEGER;
  BEGIN v := (a - b) MOD 7; IF v > 3 THEN v := v - 7 END ;
    RETURN v
  END D;

  (* 0 unison, 1 octava, 2 cvinta, 3 virgula, 4 disonant *)
  PROCEDURE Interval(r1, r2: INTEGER): INTEGER;
    VAR dx, dy, dz, k, x1, y1, z1, x2, y2, z2: INTEGER; fa, fb, q: REAL;
  BEGIN x1 := E7Txt.Ia(nodX, r1); y1 := E7Txt.Ia(nodY, r1); z1 := E7Txt.Ia(nodZ, r1);
    x2 := E7Txt.Ia(nodX, r2); y2 := E7Txt.Ia(nodY, r2); z2 := E7Txt.Ia(nodZ, r2);
    dx := D(x1, x2); dy := D(y1, y2); dz := D(z1, z2);
    IF (dx = 0) & (dy = 0) & (dz = 0) THEN k := 0
    ELSIF (dx = 0) & (dz = 0) THEN k := 1
    ELSIF (ABS(dx) = 1) & (dz = 0) THEN k := 2
    ELSE
      fa := Frec(x1, y1, z1); fb := Frec(x2, y2, z2);
      IF fa > fb THEN q := fa / fb ELSE q := fb / fa END ;
      IF q - 1.0 <= 0.013 THEN k := 3 ELSE k := 4 END
    END ;
    RETURN k
  END Interval;

  PROCEDURE NodIn(x, y, z: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN
    E7Txt.Add(d, "nod ("); E7Txt.AddInt(d, x); E7Txt.AddCh(d, ","); E7Txt.AddInt(d, y); E7Txt.AddCh(d, ",");
    E7Txt.AddInt(d, z); E7Txt.Add(d, ") · "); FrecIn(x, y, z, d); E7Txt.Add(d, " Hz · ");
    E7Txt.Add(d, domeniu[x]); E7Txt.Add(d, ", "); E7Txt.Add(d, sursaN[z])
  END NodIn;

  (* nodurile tuturor fisierelor (bucatilor) din memorie; se reface cand a mancat ceva nou *)
  PROCEDURE Harta*;
    VAR d, k, r, s, j, i, best, bc, n: INTEGER; gasit: BOOLEAN;
  BEGIN
    IF calculatLa # E7Mem.ns THEN
      IF nlDom > E7Mem.NrLeme() THEN nlDom := 0; domL := E7Txt.NouInts() END ;
      WHILE nlDom < E7Mem.NrLeme() DO
        gasit := FALSE; d := 0;
        WHILE ~gasit & (d < 7) DO
          k := 0;
          WHILE ~gasit & (k < 20) DO
            IF E7Txt.SirIncepe(E7Mem.lems, nlDom, chei[d][k]) THEN gasit := TRUE; E7Txt.Pune(domL, nlDom, d + 1) END ;
            INC(k)
          END ;
          INC(d)
        END ;
        INC(nlDom)
      END ;
      R := E7Mem.nrec; mar := E7Txt.NouInts(); cnt := E7Txt.NouInts();
      FOR s := 0 TO E7Mem.ns - 1 DO
        r := E7Mem.Rec(s);
        E7Txt.Pune(mar, r, E7Txt.Ia(mar, r) + E7Mem.Lungime(s) + 1);
        n := E7Mem.NLeme(s);
        FOR j := 0 TO n - 1 DO
          i := E7Txt.Ia(domL, E7Mem.LemaF(s, j)) - 1;
          IF i >= 0 THEN E7Txt.Pune(cnt, r * 7 + i, E7Txt.Ia(cnt, r * 7 + i) + 1) END
        END
      END ;
      nodX := E7Txt.NouInts(); nodY := E7Txt.NouInts(); nodZ := E7Txt.NouInts();
      FOR r := 0 TO R - 1 DO
        best := 6; bc := 0;
        FOR d := 0 TO 6 DO IF E7Txt.Ia(cnt, r * 7 + d) > bc THEN bc := E7Txt.Ia(cnt, r * 7 + d); best := d END END ;
        E7Txt.Pune(nodX, r, best); E7Txt.Pune(nodY, r, Marime(E7Txt.Ia(mar, r))); E7Txt.Pune(nodZ, r, Sursa(r))
      END ;
      calculatLa := E7Mem.ns
    END
  END Harta;

  PROCEDURE NodulFrazei*(s: INTEGER; VAR d: ARRAY OF CHAR);
    VAR r: INTEGER;
  BEGIN Harta; r := E7Mem.Rec(s);
    NodIn(E7Txt.Ia(nodX, r), E7Txt.Ia(nodY, r), E7Txt.Ia(nodZ, r), d)
  END NodulFrazei;

  PROCEDURE Nume(r: INTEGER; VAR d: ARRAY OF CHAR);
    VAR n: INTEGER;
  BEGIN E7Mem.RecSursa(r, src); n := E7Txt.Len(src);
    IF n > 60 THEN src[60] := 0X; E7Txt.Add(d, src); E7Txt.Add(d, "…") ELSE E7Txt.Add(d, src) END
  END Nume;

  (* f cu doua zecimale, din cifrele scrise (jumatatea in sus) *)
  PROCEDURE Zecimale(num: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR c: ARRAY 64 OF INTEGER; n, i, p, z, t: INTEGER;
  BEGIN n := 0; p := -1; i := 0;
    WHILE (num[i] # 0X) & (n < 60) DO
      IF (num[i] = ".") OR (num[i] = ",") THEN p := n ELSE c[n] := ORD(num[i]) - ORD("0"); INC(n) END ;
      INC(i)
    END ;
    IF p < 0 THEN p := n END ;
    z := n - p;                            (* cate zecimale are *)
    WHILE z < 2 DO c[n] := 0; INC(n); INC(z) END ;
    IF z > 2 THEN
      t := 0; IF c[p + 2] >= 5 THEN t := 1 END ;
      n := p + 2; i := n - 1;
      WHILE (t > 0) & (i >= 0) DO c[i] := c[i] + 1; IF c[i] = 10 THEN c[i] := 0 ELSE t := 0 END ; DEC(i) END ;
      IF t > 0 THEN FOR i := n TO 1 BY -1 DO c[i] := c[i-1] END ; c[0] := 1; INC(n); INC(p) END
    END ;
    i := 0;
    WHILE (i < p - 1) & (c[i] = 0) DO INC(i) END ;
    WHILE i < n DO IF i = p THEN E7Txt.AddCh(d, ".") END ; E7Txt.AddCh(d, CHR(ORD("0") + c[i])); INC(i) END
  END Zecimale;

  (* fisierele care raspund la o frecventa (fereastra 0,1%, ca in Roler) *)
  PROCEDURE Striga*(num: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR x, y, z, k, n, noduri, i: INTEGER; f, g, r, zec: REAL; prim: BOOLEAN;
  BEGIN Harta; d := ""; noduri := 0;
    f := 0.0; i := 0; zec := 0.0;
    WHILE num[i] # 0X DO
      IF (num[i] = ".") OR (num[i] = ",") THEN zec := 1.0
      ELSIF zec > 0.0 THEN zec := zec / 10.0; f := f + zec * FLT(ORD(num[i]) - ORD("0"))
      ELSE f := f * 10.0 + FLT(ORD(num[i]) - ORD("0"))
      END ;
      INC(i)
    END ;
    FOR x := 0 TO 6 DO FOR y := 0 TO 6 DO FOR z := 0 TO 6 DO
      g := Frec(x, y, z);
      IF f > g THEN r := f / g ELSE r := g / f END ;
      IF r - 1.0 <= 0.001 THEN
        INC(noduri); n := 0;
        FOR k := 0 TO R - 1 DO
          IF (E7Txt.Ia(nodX, k) = x) & (E7Txt.Ia(nodY, k) = y) & (E7Txt.Ia(nodZ, k) = z) & (E7Txt.Ia(mar, k) > 0) THEN INC(n) END
        END ;
        E7Txt.Add(d, "Răspunde "); NodIn(x, y, z, d); E7Txt.Add(d, ": "); E7Txt.AddInt(d, n);
        IF n = 1 THEN E7Txt.Add(d, " fișier") ELSE E7Txt.Add(d, " fișiere") END ;
        i := 0; prim := TRUE;
        FOR k := 0 TO R - 1 DO
          IF (E7Txt.Ia(nodX, k) = x) & (E7Txt.Ia(nodY, k) = y) & (E7Txt.Ia(nodZ, k) = z) & (E7Txt.Ia(mar, k) > 0) THEN
            IF i < 7 THEN
              IF prim THEN E7Txt.Add(d, " — "); prim := FALSE ELSE E7Txt.Add(d, "; ") END ;
              Nume(k, d)
            END ;
            INC(i)
          END
        END ;
        IF n > 7 THEN E7Txt.Add(d, " …") END ;
        E7Txt.AddCh(d, 0AX)
      END
    END END END ;
    IF noduri = 0 THEN
      d := "Frecvența "; Zecimale(num, d); E7Txt.Add(d, " Hz e străină de rețea: niciun nod nu răspunde (ca 440 Hz în Roler).")
    ELSE E7Txt.Trim(d)
    END
  END Striga;

  (* fisierele consonante cu fisierul r: unison, apoi octave, apoi cvinte *)
  PROCEDURE SunaCu*(r: INTEGER; VAR d: ARRAY OF CHAR);
    VAR c, k, n, i: INTEGER; numeI: ARRAY 5 OF ARRAY 16 OF CHAR;
  BEGIN Harta;
    numeI[0] := "unison"; numeI[1] := "octavă"; numeI[2] := "cvintă";
    IF (r < 0) OR (r >= R) THEN d := "Întâi întreabă-mă ceva; apoi îți spun ce sună cu fișierul din care am răspuns."
    ELSE
      d := "Fișierul „"; Nume(r, d); E7Txt.Add(d, "” stă în ");
      NodIn(E7Txt.Ia(nodX, r), E7Txt.Ia(nodY, r), E7Txt.Ia(nodZ, r), d); E7Txt.Add(d, ".");
      FOR c := 0 TO 2 DO
        n := 0;
        FOR k := 0 TO R - 1 DO IF (k # r) & (E7Txt.Ia(mar, k) > 0) & (Interval(r, k) = c) THEN INC(n) END END ;
        E7Txt.AddCh(d, 0AX); E7Txt.Add(d, numeI[c]); E7Txt.Add(d, ": "); E7Txt.AddInt(d, n);
        i := 0;
        FOR k := 0 TO R - 1 DO
          IF (k # r) & (E7Txt.Ia(mar, k) > 0) & (Interval(r, k) = c) THEN
            IF i < 5 THEN IF i = 0 THEN E7Txt.Add(d, " — ") ELSE E7Txt.Add(d, "; ") END ; Nume(k, d) END ;
            INC(i)
          END
        END ;
        IF n > 5 THEN E7Txt.Add(d, " …") END
      END
    END
  END SunaCu;

  PROCEDURE Rezumat*(VAR d: ARRAY OF CHAR);
    VAR c: ARRAY 3 OF ARRAY 7 OF INTEGER; k, a, n: INTEGER;
  BEGIN Harta; n := 0;
    FOR a := 0 TO 2 DO FOR k := 0 TO 6 DO c[a][k] := 0 END END ;
    FOR k := 0 TO R - 1 DO
      IF E7Txt.Ia(mar, k) > 0 THEN
        INC(n); INC(c[0][E7Txt.Ia(nodX, k)]); INC(c[1][E7Txt.Ia(nodY, k)]); INC(c[2][E7Txt.Ia(nodZ, k)])
      END
    END ;
    d := "Am "; E7Txt.AddInt(d, n); E7Txt.Add(d, " fișiere așezate în cub. Cvinta (domeniul): ");
    FOR k := 0 TO 6 DO IF k > 0 THEN E7Txt.Add(d, ", ") END ; E7Txt.Add(d, domeniu[k]); E7Txt.Add(d, " "); E7Txt.AddInt(d, c[0][k]) END ;
    E7Txt.AddCh(d, "."); E7Txt.AddCh(d, 0AX); E7Txt.Add(d, "Octava (mărimea, de la sub 2 KB la peste 64 KB): ");
    FOR k := 0 TO 6 DO IF k > 0 THEN E7Txt.Add(d, ", ") END ; E7Txt.AddInt(d, c[1][k]) END ;
    E7Txt.AddCh(d, "."); E7Txt.AddCh(d, 0AX); E7Txt.Add(d, "Septima (sursa): ");
    FOR k := 0 TO 6 DO IF k > 0 THEN E7Txt.Add(d, ", ") END ; E7Txt.Add(d, sursaN[k]); E7Txt.Add(d, " "); E7Txt.AddInt(d, c[2][k]) END ;
    E7Txt.Add(d, ".")
  END Rezumat;

  PROCEDURE Uita*;      (* memoria s-a schimbat de tot (import, golire): harta se reface *)
  BEGIN calculatLa := -1; nlDom := 0; domL := E7Txt.NouInts()
  END Uita;

BEGIN
  domeniu[0] := "matematică"; domeniu[1] := "fizică"; domeniu[2] := "chimie"; domeniu[3] := "biologie";
  domeniu[4] := "medicină"; domeniu[5] := "istorie"; domeniu[6] := "literatură";
  sursaN[0] := "scrierile lui Pion"; sursaN[1] := "Wikipedia"; sursaN[2] := "literatură"; sursaN[3] := "juridic";
  sursaN[4] := "medical"; sursaN[5] := "fișier importat"; sursaN[6] := "memoria veche";
  Chei(0, "număr ecuați funcți teorem matric integral derivat geometri algebr vector mulțim calcul formul matematic demonstrați probabilit statistic axiom polinom topolog");
  Chei(1, "energi forț particul und electron cuantic relativit vitez accelerați lumin fizic temperatur presiun frecvenț magnetic gravitați foton câmp masă mecanic");
  Chei(2, "substanț reacți molecul atom acid chimic compus oxigen hidrogen carbon soluți metal polimer oxid sodiu clor azot catalizator ion sare");
  Chei(3, "celul speci organism gen protein plant animal adn evoluți biologi țesut enzim bacteri mamifer ecosistem cromozom frunz pasăr insect pește");
  Chei(4, "pacient boal tratament medicament simptom diagnostic spital medic terapi doz sânge infecți cancer chirurgi clinic tiroid tumor durer vaccin afecțiun");
  Chei(5, "războ rege secol imperi domnitor armat bătăli istori revoluți regat domni popor tratat voievod dinasti cucerir împărat principat ocupați unire");
  Chei(6, "roman poezi poet scriitor carte personaj literatur vers autor oper povest teatr scen sufle inim dragost basm proz erou eminescu");
  domL := E7Txt.NouInts(); nlDom := 0; calculatLa := -1; R := 0;
  nodX := E7Txt.NouInts(); nodY := E7Txt.NouInts(); nodZ := E7Txt.NouInts(); mar := E7Txt.NouInts(); cnt := E7Txt.NouInts()
END E7Roler.


MODULE E7Motor; (* Eula 7 in Oberon: motorul. Gramatica (E7Gram) -> sorobanul 7D (E7Sor) -> Opal, supra-filtrul.
  1. Candidatele: frazele cu formele intrebarii, primele 300 dupa suma idf.
  2. Sorobanul le aseaza dupa urma lasata in cubul cu 7 dimensiuni.
  3. Opal verifica primele 7 pe 1·3·5·7·11 (cuvintele, urma, rolul cerut, fraza curata, contextul) si lasa sa treaca
     doar ce trece 3 din 5; cel mult doua fraze.  Ca in Eula 7 (Motor.java). *)

  IMPORT E7Txt, E7Mem, E7Gram, E7Sor, E7Roler, Math;

  CONST POOL = 300; OPALN = 7; OPALPRAG = 3; MaxW = E7Txt.MaxCuv; B = 65536; NB = 4096; MaxQ = 256;
    NICIUNUL = 0; CINE = 1; UNDE = 2; CAND = 3; CUCE = 4; DECE = 5; CAT = 6;

  TYPE Vorba* = PROCEDURE (intrebare: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    RBloc = POINTER TO RBlocDesc;
    RBlocDesc = RECORD a: ARRAY B OF REAL END ;

  VAR
    ultimRec*: INTEGER; sigur*: BOOLEAN;
    nota*: ARRAY 4096 OF CHAR;
    nnec*: INTEGER; nec*: ARRAY 64 OF ARRAY 256 OF CHAR;   (* cuvintele pe care nu le-a intalnit *)
    raspuns*: ARRAY 8192 OF CHAR;
    curios: ARRAY 2048 OF CHAR;        (* Fire.curios *)
    nuStiu: ARRAY 256 OF CHAR;         (* Fire.nuStiu *)
    Curios, NuStiu: Vorba;             (* le da Fire, prin Vorbe *)
    sq, sf: E7Sor.Stare;
    rolNume: ARRAY 7 OF ARRAY 32 OF CHAR;
    (* cautarea *)
    idf: ARRAY NB OF RBloc; stamp: E7Txt.Ints; st: INTEGER;
    atinse: E7Txt.Ints; nat: INTEGER;
    cand: ARRAY POOL + 1 OF INTEGER; candV: ARRAY POOL + 1 OF REAL; ncand: INTEGER;
    sc: ARRAY POOL OF INTEGER;
    qIds: ARRAY MaxQ OF INTEGER; nq: INTEGER;
    trec: ARRAY 2 OF INTEGER; ntrec: INTEGER;
    w, x, tmp, grup: ARRAY MaxW OF CHAR;
    fr: ARRAY 8192 OF CHAR;
    fa, fb: ARRAY 4096 OF CHAR;
    toks: ARRAY 256 OF ARRAY 440 OF CHAR; nt: INTEGER;   (* cuvintele unei fraze, pentru Opal *)

  (* ---------- ajutoare ---------- *)

  PROCEDURE IdfIa(s: INTEGER): REAL;
  BEGIN RETURN idf[s DIV B].a[s MOD B]
  END IdfIa;

  PROCEDURE IdfPune(s: INTEGER; v: REAL);
  BEGIN
    IF idf[s DIV B] = NIL THEN NEW(idf[s DIV B]) END ;
    idf[s DIV B].a[s MOD B] := v
  END IdfPune;

  PROCEDURE InQ(id: INTEGER): BOOLEAN;
    VAR k: INTEGER; da: BOOLEAN;
  BEGIN k := 0; da := FALSE;
    WHILE ~da & (k < nq) DO da := qIds[k] = id; INC(k) END ;
    RETURN da
  END InQ;

  PROCEDURE NecAre(s: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER; da: BOOLEAN;
  BEGIN k := 0; da := FALSE;
    WHILE ~da & (k < nnec) DO da := E7Txt.Eq(nec[k], s); INC(k) END ;
    RETURN da
  END NecAre;

  PROCEDURE NecPune(s: ARRAY OF CHAR);
  BEGIN IF nnec < LEN(nec) THEN E7Txt.Copy(s, nec[nnec]); INC(nnec) END
  END NecPune;

  (* cuvintele frazei (Memorie.tokeni) in toks *)
  PROCEDURE Cuvinte(s: ARRAY OF CHAR);
    VAR k: INTEGER;
  BEGIN E7Mem.Tokeni(s); nt := 0;
    FOR k := 0 TO E7Mem.ntok - 1 DO IF nt < LEN(toks) THEN E7Mem.Tok(k, toks[nt]); INC(nt) END END
  END Cuvinte;

  (* \b inainte si dupa: s[i-1] si s[j] nu sunt semne de cuvant *)
  PROCEDURE Margine(s: ARRAY OF CHAR; i: INTEGER): BOOLEAN;
    VAR a, b: BOOLEAN;
  BEGIN
    a := (i > 0) & E7Txt.Cuv(s[i-1]);
    b := (i < LEN(s)) & (s[i] # 0X) & E7Txt.Cuv(s[i]);
    RETURN a # b
  END Margine;

  (* ^(alt1|alt2|...)\b.* *)
  PROCEDURE Incepe(q, alts: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER; da, gasit: BOOLEAN;
  BEGIN i := 0; gasit := FALSE;
    WHILE ~gasit & (alts[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (alts[i] # 0X) & (alts[i] # "|") DO
        IF da & (q[j] = alts[i]) & (q[j] # 0X) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da & Margine(q, j) THEN gasit := TRUE END ;
      IF alts[i] = "|" THEN INC(i) END
    END ;
    RETURN gasit
  END Incepe;

  (* ---------- rolul cerut de intrebare (kāraka) ---------- *)

  PROCEDURE Rol(intrebare: ARRAY OF CHAR): INTEGER;
    VAR i, j, r: INTEGER; c: CHAR; sp: BOOLEAN;
  BEGIN
    i := 0; j := 0; sp := TRUE;    (* fold(lower), [^a-z0-9 ] -> spatiu, \s+ -> un spatiu, trim *)
    WHILE (i < LEN(intrebare)) & (intrebare[i] # 0X) DO
      c := E7Txt.Fold(E7Txt.Mic(intrebare[i]));
      IF ~((c >= "a") & (c <= "z") OR (c >= "0") & (c <= "9")) THEN c := " " END ;
      IF c = " " THEN
        IF ~sp THEN fr[j] := " "; INC(j); sp := TRUE END
      ELSE fr[j] := c; INC(j); sp := FALSE
      END ;
      INC(i)
    END ;
    IF (j > 0) & (fr[j-1] = " ") THEN DEC(j) END ;
    fr[j] := 0X;
    IF Incepe(fr, "cine|pe cine|cui|de catre cine|al cui|a cui") THEN r := CINE
    ELSIF Incepe(fr, "unde|de unde|in ce loc|in ce tara|in ce oras|pe unde") THEN r := UNDE
    ELSIF Incepe(fr, "cand|in ce an|in ce secol|in ce perioada|de cand|pana cand") THEN r := CAND
    ELSIF Incepe(fr, "cu ce|prin ce|cum|cu ajutorul") THEN r := CUCE
    ELSIF Incepe(fr, "de ce|din ce cauza|pentru ce") THEN r := DECE
    ELSIF Incepe(fr, "cat|cati|cate|cata") THEN r := CAT
    ELSE r := NICIUNUL
    END ;
    RETURN r
  END Rol;

  (* un cuvant (ca in \b...\b) facut doar din cifre ASCII, cu lungimea intre lo si hi *)
  PROCEDURE AreNumar(s: ARRAY OF CHAR; lo, hi: INTEGER): BOOLEAN;
    VAR i, j, n: INTEGER; da, numai: BOOLEAN;
  BEGIN n := E7Txt.Len(s); i := 0; da := FALSE;
    WHILE ~da & (i < n) DO
      IF E7Txt.Cuv(s[i]) THEN
        j := i; numai := TRUE;
        WHILE (j < n) & E7Txt.Cuv(s[j]) DO IF ~((s[j] >= "0") & (s[j] <= "9")) THEN numai := FALSE END ; INC(j) END ;
        IF numai & (j - i >= lo) & (j - i <= hi) THEN da := TRUE END ;
        i := j
      ELSE INC(i)
      END
    END ;
    RETURN da
  END AreNumar;

  (* are fraza un semn al rolului cerut? *)
  PROCEDURE SemnRol(r: INTEGER; fraza: ARRAY OF CHAR): BOOLEAN;
    VAR da: BOOLEAN; i, j, k, n: INTEGER;
  BEGIN
    IF r = NICIUNUL THEN da := TRUE
    ELSE
      Cuvinte(fraza);
      fr := " "; i := 0; n := E7Txt.Len(fraza); j := 1;
      WHILE (i < n) & (j < LEN(fr) - 2) DO fr[j] := E7Txt.Fold(E7Txt.Mic(fraza[i])); INC(i); INC(j) END ;
      fr[j] := " "; fr[j+1] := 0X;
      da := FALSE;
      IF r = CINE THEN
        (* fraza.split("\\s+"), de la al doilea: incepe cu majuscula, nu e din intrebare *)
        i := 0; k := 0;
        WHILE ~da & (i < n) DO
          WHILE (i < n) & E7Txt.Spatiu(fraza[i]) DO INC(i) END ;
          j := 0;
          WHILE (i < n) & ~E7Txt.Spatiu(fraza[i]) DO IF j < MaxW - 1 THEN w[j] := fraza[i]; INC(j) END ; INC(i) END ;
          w[j] := 0X;
          IF j > 0 THEN
            IF (k >= 1) & (j > 1) & E7Txt.Majuscula(w[0]) THEN
              n := 0; j := 0;
              WHILE w[j] # 0X DO IF E7Txt.Litera(w[j]) THEN x[n] := w[j]; INC(n) END ; INC(j) END ;
              x[n] := 0X; n := E7Txt.Len(fraza);
              IF ~InQ(E7Mem.Cauta(x)) THEN da := TRUE END
            END ;
            INC(k)
          END
        END ;
        k := 0;
        WHILE ~da & (k < nt) DO
          IF E7Gram.Nume(toks[k]) & E7Mem.Continut(toks[k]) & ~InQ(E7Mem.Cauta(toks[k])) THEN da := TRUE END ;
          INC(k)
        END
      ELSIF r = UNDE THEN
        k := 0;
        WHILE ~da & (k + 1 < nt) DO
          IF E7Txt.InLista(toks[k], "în|in|la|pe|din|lângă|langa|spre|între|intre|sub|peste") & E7Mem.Continut(toks[k+1])
            & ~InQ(E7Mem.Cauta(toks[k+1])) THEN da := TRUE END ;
          INC(k)
        END
      ELSIF r = CAND THEN
        IF AreNumar(fr, 2, 4) OR E7Txt.Contine(fr, " secol") THEN da := TRUE END ;
        k := 0;
        WHILE ~da & (k < nt) DO
          E7Mem.Fold(toks[k], x);
          IF (E7Txt.Len(toks[k]) >= 3) & E7Txt.Contine("ianuarie februarie martie aprilie mai iunie iulie august septembrie octombrie noiembrie decembrie", x) THEN da := TRUE END ;
          INC(k)
        END
      ELSIF r = CUCE THEN
        da := E7Txt.Contine(fr, " cu ") OR E7Txt.Contine(fr, " prin ") OR E7Txt.Contine(fr, " folosind ") OR E7Txt.Contine(fr, " utilizand ")
      ELSIF r = DECE THEN
        da := E7Txt.Contine(fr, " pentru ca ") OR E7Txt.Contine(fr, " deoarece ") OR E7Txt.Contine(fr, " din cauza ") OR E7Txt.Contine(fr, " datorita ")
          OR E7Txt.Contine(fr, " fiindca ") OR E7Txt.Contine(fr, " caci ") OR E7Txt.Contine(fr, " intrucat ") OR E7Txt.Contine(fr, " ca urmare ")
      ELSIF r = CAT THEN
        da := AreNumar(fr, 1, 1000000) OR E7Txt.Contine(fr, " unu ") OR E7Txt.Contine(fr, " doi ") OR E7Txt.Contine(fr, " doua ")
          OR E7Txt.Contine(fr, " trei ") OR E7Txt.Contine(fr, " patru ") OR E7Txt.Contine(fr, " cinci ") OR E7Txt.Contine(fr, " sase ")
          OR E7Txt.Contine(fr, " sapte ") OR E7Txt.Contine(fr, " opt ") OR E7Txt.Contine(fr, " noua ") OR E7Txt.Contine(fr, " zece ")
          OR E7Txt.Contine(fr, " suta ") OR E7Txt.Contine(fr, " sute ") OR E7Txt.Contine(fr, " mie ") OR E7Txt.Contine(fr, " mii ")
          OR E7Txt.Contine(fr, " milion ") OR E7Txt.Contine(fr, " milioane ")
      END
    END ;
    RETURN da
  END SemnRol;

  (* ---------- definitiile ---------- *)

  (* „X este …”: X (orice forma) printre primele 4 cuvinte, fara posesiv dupa el, urmat curand de „este/reprezintă…” *)
  PROCEDURE Definitie(s, id: INTEGER): BOOLEAN;
    VAR i, j, n, r: INTEGER;
  BEGIN E7Mem.Fraza(s, fa); Cuvinte(fa); r := 0; i := 0;
    n := nt; IF n > 4 THEN n := 4 END ;
    WHILE (r = 0) & (i < n) DO
      IF E7Mem.Cauta(toks[i]) = id THEN
        j := i + 1; r := -1;
        WHILE (r = -1) & (j < i + 5) & (j < nt) DO
          IF E7Txt.InLista(toks[j], "ei|lui|lor|sa|său|sau|sale|săi|mea|meu|ta|tău|noastră|nostru|voastră|acestuia|acesteia|acestora") THEN r := -2
          ELSIF E7Txt.InLista(toks[j], "este|e|sunt|reprezintă|reprezinta|înseamnă|inseamna|desemnează|desemneaza|era|constituie|denumește|denumeste") THEN r := 1
          END ;
          INC(j)
        END
      END ;
      INC(i)
    END ;
    RETURN r = 1
  END Definitie;

  PROCEDURE Spune(VAR d: ARRAY OF CHAR);
    VAR k: INTEGER;
  BEGIN d := ""; fb := "";
    FOR k := 0 TO ntrec - 1 DO
      E7Mem.Fraza(trec[k], fa);
      IF ~E7Txt.Eq(fa, fb) OR (k = 0) THEN
        IF E7Txt.Len(d) > 0 THEN E7Txt.Add(d, " ") END ;
        E7Txt.Add(d, fa); E7Txt.Copy(fa, fb)
      END
    END
  END Spune;

  (* cele 5 verificari ale lui Opal: corpuscul, unda, rol, curata, context; intoarce cate au trecut *)
  PROCEDURE Verifica(s, lit, scor, r: INTEGER; VAR v: ARRAY OF INTEGER): INTEGER;
    VAR k, comune, n, litere, fara, d, u: INTEGER; areVerb, ctx: BOOLEAN;
  BEGIN
    FOR k := 0 TO 4 DO v[k] := 0 END ;
    comune := 0; FOR k := 0 TO nq - 1 DO IF E7Mem.Are(s, qIds[k]) THEN INC(comune) END END ;
    k := (nq + 1) DIV 2; IF k < 1 THEN k := 1 END ;
    IF comune >= k THEN v[0] := 1 END ;
    IF (lit > 0) & (scor >= lit) THEN v[1] := 1 END ;
    E7Mem.Fraza(s, fa);
    IF SemnRol(r, fa) THEN v[2] := 1 END ;
    Cuvinte(fa);
    n := E7Txt.Len(fa); litere := 0; fara := 0;
    FOR k := 0 TO n - 1 DO
      IF E7Txt.Litera(fa[k]) THEN INC(litere) END ;
      IF fa[k] # " " THEN INC(fara) END
    END ;
    areVerb := FALSE; k := 0;
    WHILE ~areVerb & (k < nt) DO areVerb := E7Gram.Verb(toks[k]); INC(k) END ;
    IF (n >= 20) & (n <= 420) & (nt >= 5) & (10 * litere >= 7 * fara) & areVerb THEN v[3] := 1 END ;
    ctx := FALSE; d := -1;
    WHILE ~ctx & (d <= 1) DO
      u := s + d;
      IF (u >= 0) & (u < E7Mem.ns) & (E7Mem.Rec(u) = E7Mem.Rec(s)) THEN
        k := 0; WHILE ~ctx & (k < nq) DO IF E7Mem.Are(u, qIds[k]) THEN ctx := TRUE END ; INC(k) END
      END ;
      d := d + 2
    END ;
    IF ctx THEN v[4] := 1 END ;
    RETURN v[0] + v[1] + v[2] + v[3] + v[4]
  END Verifica;

  PROCEDURE Semne(v: ARRAY OF INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER; prim: BOOLEAN; n: ARRAY 5 OF ARRAY 4 OF CHAR;
  BEGIN n[0] := "1"; n[1] := "3"; n[2] := "5"; n[3] := "7"; n[4] := "11"; prim := TRUE;
    FOR i := 0 TO 4 DO
      IF v[i] = 1 THEN IF ~prim THEN E7Txt.Add(d, "·") END ; E7Txt.Add(d, n[i]); prim := FALSE END
    END
  END Semne;

  (* sorobanul: starea unei fraze (formele ei de baza) *)
  PROCEDURE StareFraza(st: E7Sor.Stare; s: INTEGER);
    VAR k: INTEGER;
  BEGIN E7Sor.Goleste(st);
    FOR k := 0 TO E7Mem.NLeme(s) - 1 DO E7Mem.Lema(E7Mem.LemaF(s, k), x); E7Sor.Cuvant(st, x) END
  END StareFraza;

  (* candidata s, cu valoarea v, intra in primele POOL (idf descrescator, apoi s crescator) *)
  PROCEDURE Candidata(s: INTEGER; v: REAL);
    VAR i: INTEGER;
  BEGIN
    IF (ncand < POOL) OR (v > candV[ncand - 1]) OR (v = candV[ncand - 1]) & (s < cand[ncand - 1]) THEN
      i := ncand; IF i = POOL THEN DEC(i) ELSE INC(ncand) END ;
      WHILE (i > 0) & ((candV[i-1] < v) OR (candV[i-1] = v) & (cand[i-1] > s)) DO
        cand[i] := cand[i-1]; candV[i] := candV[i-1]; DEC(i)
      END ;
      cand[i] := s; candV[i] := v
    END
  END Candidata;

  (* cautarea obisnuita; doar = id-ul unui cuvant care trebuie sa fie in fraza (sau -1) *)
  PROCEDURE Cauta(intrebare: ARRAY OF CHAR; doar: INTEGER; VAR d: ARRAY OF CHAR);
    VAR k, id, p, s, L, lit, i, j, t, r, n: INTEGER; f: REAL; v: ARRAY 5 OF INTEGER; jurnal: ARRAY 64 OF CHAR; dublura: BOOLEAN;
  BEGIN
    nq := 0;
    E7Mem.Tokeni(intrebare);
    FOR k := 0 TO E7Mem.ntok - 1 DO
      E7Mem.Tok(k, w);
      IF E7Mem.Continut(w) & ~E7Mem.Cerere(w) THEN
        id := E7Mem.Cauta(w);
        IF (id < 0) & E7Txt.Litera(w[0]) & ~NecAre(w) THEN NecPune(w) END ;
        IF (id >= 0) & ~InQ(id) & (nq < MaxQ) THEN qIds[nq] := id; INC(nq) END
      END ;
      E7Mem.Tokeni(intrebare)          (* Cauta poate folosi tokenii: ii refac *)
    END ;
    IF nq = 0 THEN
      IF nnec > 0 THEN nota := "cuvinte necunoscute"; Curios(intrebare, curios); E7Txt.Copy(curios, d)
      ELSE d := "Nu știu încă nimic despre asta. Hrănește-mă cu ceva despre "; E7Txt.Copy(intrebare, tmp); E7Txt.Trim(tmp);
        E7Txt.Add(d, tmp); E7Txt.Add(d, ".")
      END
    ELSE
      (* 1. candidatele: suma idf *)
      INC(st); nat := 0;
      FOR k := 0 TO nq - 1 DO
        id := qIds[k]; n := E7Mem.PostN(id); IF n < 1 THEN n := 1 END ;
        f := Math.ln(1.0 + FLT(E7Mem.ns) / FLT(n));
        p := E7Mem.Prima(id);
        WHILE p >= 0 DO
          s := E7Mem.PF(p);
          IF E7Txt.Ia(stamp, s) # st THEN E7Txt.Pune(stamp, s, st); IdfPune(s, 0.0); E7Txt.Pune(atinse, nat, s); INC(nat) END ;
          IdfPune(s, IdfIa(s) + f);
          p := E7Mem.Urm(p)
        END
      END ;
      ncand := 0;
      FOR k := 0 TO nat - 1 DO
        s := E7Txt.Ia(atinse, k); L := E7Mem.Lungime(s);
        IF (L >= 20) & (L <= 420) & ((doar < 0) OR E7Mem.Are(s, doar)) THEN Candidata(s, IdfIa(s)) END
      END ;
      IF ncand = 0 THEN d := "N-am citit încă nimic despre asta."
      ELSE
        (* 2. sorobanul 7D *)
        E7Sor.Goleste(sq);
        FOR k := 0 TO nq - 1 DO E7Mem.Lema(qIds[k], x); E7Sor.Cuvant(sq, x) END ;
        lit := E7Sor.Aprinse(sq);
        FOR k := 0 TO ncand - 1 DO StareFraza(sf, cand[k]); sc[k] := E7Sor.Scor(sq, sf) END ;
        FOR i := 1 TO ncand - 1 DO            (* scor descrescator, apoi s crescator *)
          s := cand[i]; t := sc[i]; j := i - 1;
          WHILE (j >= 0) & ((sc[j] < t) OR (sc[j] = t) & (cand[j] > s)) DO cand[j+1] := cand[j]; sc[j+1] := sc[j]; DEC(j) END ;
          cand[j+1] := s; sc[j+1] := t
        END ;
        (* 3. Opal *)
        r := Rol(intrebare); ntrec := 0; jurnal := "";
        k := 0;
        WHILE (k < OPALN) & (k < ncand) & (ntrec < 2) DO
          s := cand[k];
          IF Verifica(s, lit, sc[k], r, v) >= OPALPRAG THEN
            dublura := FALSE; E7Mem.Fraza(s, fa);
            FOR i := 0 TO ntrec - 1 DO E7Mem.Fraza(trec[i], fb); IF E7Txt.Eq(fa, fb) THEN dublura := TRUE END END ;
            IF ~dublura THEN
              trec[ntrec] := s; INC(ntrec);
              IF jurnal = "" THEN Semne(v, jurnal) END
            END
          END ;
          INC(k)
        END ;
        IF ntrec = 0 THEN
          ultimRec := E7Mem.Rec(cand[0]);
          nota := "Opal: nicio frază n-a trecut 3 din 5 · "; E7Mem.Sursa(cand[0], tmp); E7Txt.Add(nota, tmp);
          E7Txt.Add(nota, " · "); E7Roler.NodulFrazei(cand[0], nota);
          NuStiu(intrebare, nuStiu); E7Txt.Copy(nuStiu, d); E7Txt.Add(d, " Cel mai aproape am găsit: ");
          E7Mem.Fraza(cand[0], fa); E7Txt.Add(d, fa)
        ELSE
          sigur := TRUE;
          IF (ntrec = 2) & (trec[1] < trec[0]) THEN s := trec[0]; trec[0] := trec[1]; trec[1] := s END ;
          ultimRec := E7Mem.Rec(trec[0]);
          nota := "Opal "; E7Txt.Add(nota, jurnal);
          IF r # NICIUNUL THEN E7Txt.Add(nota, " · rol: "); E7Txt.Add(nota, rolNume[r]) END ;
          E7Txt.Add(nota, " · "); E7Mem.Sursa(trec[0], tmp); E7Txt.Add(nota, tmp);
          E7Txt.Add(nota, " · "); E7Roler.NodulFrazei(trec[0], nota);
          Spune(d)
        END
      END
    END
  END Cauta;

  PROCEDURE Defineste(cuvant, intrebare: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR id, p, s, best, bs, scr, nc: INTEGER;
  BEGIN id := E7Mem.Cauta(cuvant);
    IF id < 0 THEN
      NecPune(cuvant); nota := "cuvânt necunoscut"; Curios(intrebare, curios); E7Txt.Copy(curios, d)
    ELSE
      nc := 0; best := -1; bs := -2147483647;   (* Eula 7 pornea de la -1 si cadea cand niciun scor nu trecea de -1 *)
      E7Sor.Goleste(sq); E7Mem.Lema(id, x); E7Sor.Cuvant(sq, x);
      p := E7Mem.Prima(id);
      WHILE p >= 0 DO
        s := E7Mem.PF(p);
        IF (E7Mem.Lungime(s) >= 20) & (E7Mem.Lungime(s) <= 420) & Definitie(s, id) THEN
          INC(nc);
          StareFraza(sf, s);
          scr := E7Sor.Scor(sq, sf) * 1000 - E7Mem.Lungime(s);     (* la egalitate, cea mai scurta *)
          IF scr > bs THEN bs := scr; best := s END
        END ;
        p := E7Mem.Urm(p)
      END ;
      IF nc = 0 THEN
        nota := "n-am o frază de forma „"; E7Mem.Lema(id, x); E7Txt.Add(nota, x); E7Txt.Add(nota, " este …”; iată ce am citit");
        Cauta(intrebare, id, d)
      ELSE
        sigur := TRUE; ultimRec := E7Mem.Rec(best);
        nota := "definiție din memorie ("; E7Txt.AddInt(nota, nc); E7Txt.Add(nota, " fraze „"); E7Mem.Lema(id, x); E7Txt.Add(nota, x);
        E7Txt.Add(nota, " este …”) · "); E7Mem.Sursa(best, tmp); E7Txt.Add(nota, tmp); E7Txt.Add(nota, " · ");
        E7Roler.NodulFrazei(best, nota);
        E7Mem.Fraza(best, d)
      END
    END
  END Defineste;

  (* ^(prefix)(.+?)\s*[?.!]*$ : daca q incepe cu prefix, grupul (cel mai scurt) in grup *)
  PROCEDURE Def(q, prefix: ARRAY OF CHAR): BOOLEAN;
    VAR n, m, k, i: INTEGER; da: BOOLEAN;
  BEGIN n := E7Txt.Len(q); m := E7Txt.Len(prefix); da := FALSE;
    IF (n > m) & E7Txt.Incepe(q, prefix) THEN
      k := m + 1;
      WHILE ~da DO                         (* coada q[k..n) = \s*[?.!]* *)
        i := k; WHILE (i < n) & E7Txt.Spatiu(q[i]) DO INC(i) END ;
        WHILE (i < n) & ((q[i] = "?") OR (q[i] = ".") OR (q[i] = "!")) DO INC(i) END ;
        IF i = n THEN da := TRUE ELSE INC(k) END
      END ;
      E7Txt.Sub(q, m, k, grup)
    END ;
    RETURN da
  END Def;

  PROCEDURE Raspunde*(intrebare: ARRAY OF CHAR);
    VAR i, j, k: INTEGER; c: CHAR; gasit: BOOLEAN; ultim: ARRAY MaxW OF CHAR;
  BEGIN
    nota := ""; sigur := FALSE; nnec := 0; raspuns := "";
    (* qf = fold(lower).trim(), fara „ ” " *)
    i := 0; j := 0;
    WHILE (i < LEN(intrebare)) & (intrebare[i] # 0X) & (j < LEN(fr) - 1) DO
      c := E7Txt.Fold(E7Txt.Mic(intrebare[i])); fr[j] := c; INC(j); INC(i)
    END ;
    fr[j] := 0X; E7Txt.Trim(fr);
    i := 0; j := 0;
    WHILE fr[i] # 0X DO
      c := fr[i]; IF ~((c = CHR(201EH)) OR (c = CHR(201DH)) OR (c = 22X)) THEN fr[j] := c; INC(j) END ; INC(i)
    END ;
    fr[j] := 0X;
    gasit := Def(fr, "ce este ") OR Def(fr, "ce e ") OR Def(fr, "ce inseamna ") OR Def(fr, "ce reprezinta ") OR Def(fr, "ce sunt ")
      OR Def(fr, "defineste cuvantul ") OR Def(fr, "defineste ")
      OR Def(fr, "definitia lui ") OR Def(fr, "definitia cuvantului ") OR Def(fr, "definitia ")
      OR Def(fr, "ce stii despre ")
      OR Def(fr, "explica-mi ce e ") OR Def(fr, "explica-mi ce este ") OR Def(fr, "explica-mi ")
      OR Def(fr, "explica ce e ") OR Def(fr, "explica ce este ") OR Def(fr, "explica ");
    k := 0;
    IF gasit THEN
      E7Mem.Tokeni(grup); ultim := "";
      FOR i := 0 TO E7Mem.ntok - 1 DO
        E7Mem.Tok(i, w);
        IF E7Mem.Continut(w) THEN E7Txt.Copy(w, ultim); INC(k) END ;
        E7Mem.Tokeni(grup)
      END
    END ;
    IF k > 0 THEN Defineste(ultim, intrebare, raspuns)
    ELSE Cauta(intrebare, -1, raspuns)
    END
  END Raspunde;

  PROCEDURE Vorbe*(curios, nuStiu: Vorba);
  BEGIN Curios := curios; NuStiu := nuStiu
  END Vorbe;

  PROCEDURE Pregateste*;
  BEGIN
    IF sq = NIL THEN sq := E7Sor.Nou(); sf := E7Sor.Nou() END
  END Pregateste;

BEGIN
  rolNume[0] := ""; rolNume[1] := "cine (kartṛ)"; rolNume[2] := "unde (adhikaraṇa)"; rolNume[3] := "când (adhikaraṇa)";
  rolNume[4] := "cu ce (karaṇa)"; rolNume[5] := "de ce (hetu)"; rolNume[6] := "cât";
  stamp := E7Txt.NouInts(); atinse := E7Txt.NouInts(); st := 0; ultimRec := -1; nnec := 0;
  sq := NIL; sf := NIL
END E7Motor.


MODULE E7Fire; (* Eula 7 in Oberon: firea (ca Fire.java). Personalitatea creste din ce e ea cu adevarat: un cub care
  tine minte fraze. Trei trasaturi: sincera (spune de unde stie si cand nu stie), curioasa (cere cuvintele pe care nu
  le-a intalnit), copil care stie ca e copil. Tot ce spune despre ea se calculeaza din starea ei reala.
  Nu pretinde sentimente, nu flateaza, n-are pareri. *)

  IMPORT E7Txt, E7Mem, E7Motor, E7Roler, E7Disc;

  CONST NASTERE = "12 octombrie 2026"; MaxC = 2048; N = 4096;
    NIMIC* = 0; GATA* = 1; INVATA* = 2;
    INTREBARE = "ce|cine|cum|cand|unde|de ce|cat|cati|cate|care|oare|poti|stii|ai|esti|exista";

  VAR
    nume*: ARRAY 64 OF CHAR;                 (* "" = nu mi-a spus *)
    intrebari*, nustiu*, invatate*: INTEGER;
    cerute: ARRAY MaxC OF ARRAY 256 OF CHAR; ncer: INTEGER;
    store: ARRAY 1100 OF CHAR;
    astept: BOOLEAN;
    fel*: INTEGER;                           (* NIMIC, GATA (r0, r1), INVATA *)
    r0*, r1*: ARRAY 16384 OF CHAR;
    q, fr, rest, restRaw, t, tr, x, g1: ARRAY N OF CHAR;
    salut: ARRAY 256 OF CHAR;
    nsSurse: INTEGER; surse: ARRAY 1024 OF CHAR;
    (* surse(): cheile si cate fraze *)
    kSir: ARRAY 4096 OF ARRAY 64 OF CHAR; kNr, kOrd: ARRAY 4096 OF INTEGER; nk: INTEGER;
    recNr: E7Txt.Ints;
    linie: ARRAY 4096 OF CHAR;

  (* ---------- tinut minte intre porniri (fire.txt) ---------- *)

  PROCEDURE CerAre(s: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER; da: BOOLEAN;
  BEGIN k := 0; da := FALSE;
    WHILE ~da & (k < ncer) DO da := E7Txt.Eq(cerute[k], s); INC(k) END ;
    RETURN da
  END CerAre;

  PROCEDURE Cere*(s: ARRAY OF CHAR);       (* cerute.add(s) *)
  BEGIN
    IF ~CerAre(s) & (ncer < MaxC) THEN E7Txt.Copy(s, cerute[ncer]); INC(ncer) END
  END Cere;

  PROCEDURE Int(s: ARRAY OF CHAR): INTEGER;
    VAR i, r: INTEGER;
  BEGIN i := 0; r := 0;
    WHILE s[i] = " " DO INC(i) END ;
    WHILE (s[i] >= "0") & (s[i] <= "9") DO r := r * 10 + ORD(s[i]) - ORD("0"); INC(i) END ;
    RETURN r
  END Int;

  PROCEDURE RandFire(VAR l: ARRAY OF CHAR);
    VAR i: INTEGER; cheie, v: ARRAY 4096 OF CHAR;
  BEGIN i := 0;
    WHILE (l[i] # 0X) & (l[i] # 9X) DO INC(i) END ;
    IF l[i] = 9X THEN
      E7Txt.Sub(l, 0, i, cheie); E7Txt.Sub(l, i + 1, E7Txt.Len(l), v);
      IF E7Txt.Eq(cheie, "nume") THEN E7Txt.Copy(v, nume)
      ELSIF E7Txt.Eq(cheie, "intrebari") THEN intrebari := Int(v)
      ELSIF E7Txt.Eq(cheie, "nustiu") THEN nustiu := Int(v)
      ELSIF E7Txt.Eq(cheie, "invatate") THEN invatate := Int(v)
      ELSIF E7Txt.Eq(cheie, "cerut") THEN Cere(v)
      END
    END
  END RandFire;

  PROCEDURE Incarca*(cale: ARRAY OF CHAR);
    VAR b, c, n: INTEGER;
  BEGIN E7Txt.Copy(cale, store);
    IF E7Disc.Citeste(cale) THEN
      n := 0; b := E7Disc.Octet();
      WHILE b >= 0 DO
        IF b < 80H THEN c := b
        ELSIF b < 0E0H THEN c := (b MOD 32) * 64 + E7Disc.Octet() MOD 64
        ELSIF b < 0F0H THEN c := (b MOD 16) * 1000H; c := c + (E7Disc.Octet() MOD 64) * 64; c := c + E7Disc.Octet() MOD 64
        ELSE c := 0FFFDH
        END ;
        IF c = 0AH THEN linie[n] := 0X; RandFire(linie); n := 0
        ELSIF c # 0DH THEN IF n < LEN(linie) - 1 THEN linie[n] := CHR(c); INC(n) END
        END ;
        b := E7Disc.Octet()
      END ;
      IF n > 0 THEN linie[n] := 0X; RandFire(linie) END ;
      E7Disc.InchideC
    END
  END Incarca;

  PROCEDURE Salveaza*;
    VAR k: INTEGER; s: ARRAY 32 OF CHAR;
  BEGIN
    IF (store # "") & E7Disc.Scrie(store) THEN
      IF nume # "" THEN E7Disc.PuneUtf8("nume"); E7Disc.Pune(9); E7Disc.PuneUtf8(nume); E7Disc.Pune(10) END ;
      s := ""; E7Txt.AddInt(s, intrebari); E7Disc.PuneUtf8("intrebari"); E7Disc.Pune(9); E7Disc.PuneUtf8(s); E7Disc.Pune(10);
      s := ""; E7Txt.AddInt(s, nustiu); E7Disc.PuneUtf8("nustiu"); E7Disc.Pune(9); E7Disc.PuneUtf8(s); E7Disc.Pune(10);
      s := ""; E7Txt.AddInt(s, invatate); E7Disc.PuneUtf8("invatate"); E7Disc.Pune(9); E7Disc.PuneUtf8(s); E7Disc.Pune(10);
      FOR k := 0 TO ncer - 1 DO
        IF k < 50 THEN E7Disc.PuneUtf8("cerut"); E7Disc.Pune(9); E7Disc.PuneUtf8(cerute[k]); E7Disc.Pune(10) END
      END ;
      E7Disc.Inchide
    END
  END Salveaza;

  (* ---------- vorbele ---------- *)

  PROCEDURE Seed*(s: ARRAY OF CHAR): INTEGER;    (* s.hashCode() & 0x7fffffff *)
    VAR h: INTEGER;
  BEGIN h := E7Txt.Hash(s);
    IF h < 0 THEN h := h + 2147483647; h := h + 1 END ;
    RETURN h
  END Seed;

  (* Fire.norm: fold(lower), [^a-z0-9 -] -> spatiu, \s+ -> un spatiu, trim *)
  PROCEDURE Norm*(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i, j: INTEGER; c: CHAR; sp: BOOLEAN;
  BEGIN i := 0; j := 0; sp := TRUE;
    WHILE (i < LEN(s)) & (s[i] # 0X) & (j < LEN(d) - 1) DO
      c := E7Txt.Fold(E7Txt.Mic(s[i]));
      IF ~((c >= "a") & (c <= "z") OR (c >= "0") & (c <= "9") OR (c = " ") OR (c = "-")) THEN c := " " END ;
      IF c = " " THEN
        IF ~sp THEN d[j] := " "; INC(j); sp := TRUE END
      ELSE d[j] := c; INC(j); sp := FALSE
      END ;
      INC(i)
    END ;
    IF (j > 0) & (d[j-1] = " ") THEN DEC(j) END ;
    d[j] := 0X
  END Norm;

  PROCEDURE Tu(VAR d: ARRAY OF CHAR);
  BEGIN IF nume # "" THEN E7Txt.Add(d, ", "); E7Txt.Add(d, nume) END
  END Tu;

  (* aceeasi intrebare -> aceeasi formulare: v[seed mod n], variantele despartite de "|" *)
  PROCEDURE Pick(seed: INTEGER; v: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR n, i, k, j: INTEGER;
  BEGIN n := 1; i := 0;
    WHILE v[i] # 0X DO IF v[i] = "|" THEN INC(n) END ; INC(i) END ;
    k := seed MOD n; i := 0;
    WHILE k > 0 DO IF v[i] = "|" THEN DEC(k) END ; INC(i) END ;
    j := E7Txt.Len(d);
    WHILE (v[i] # 0X) & (v[i] # "|") & (j < LEN(d) - 1) DO d[j] := v[i]; INC(j); INC(i) END ;
    d[j] := 0X
  END Pick;

  (* cand Opal n-a lasat nicio fraza sa treaca *)
  PROCEDURE NuStiu(intrebare: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  BEGIN d := "";
    Pick(Seed(intrebare), "Nu știu sigur.|Nu știu sigur.|Nu știu sigur.|Piatra soarelui n-a vrut să sară: nu știu sigur.|Opal m-a oprit, deci nu știu sigur.", d)
  END NuStiu;

  (* cand intrebarea are cuvinte pe care nu le-a intalnit niciodata *)
  PROCEDURE Curios(intrebare: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR s: INTEGER;
  BEGIN s := Seed(intrebare); d := "";
    CASE s MOD 3 OF
      0: d := "N-am dat niciodată de „"; E7Txt.Add(d, E7Motor.nec[0]); E7Txt.Add(d, "”. Mi-l explici?")
    | 1: d := "Ce e „"; E7Txt.Add(d, E7Motor.nec[0]); E7Txt.Add(d, "”? N-am întâlnit cuvântul ăsta niciodată.")
    | 2: d := "Cuvânt nou pentru mine: „"; E7Txt.Add(d, E7Motor.nec[0]); E7Txt.Add(d, "”. Mi-l spui?")
    END ;
    E7Txt.Add(d, " Scrie „"); E7Txt.Add(d, E7Motor.nec[0]); E7Txt.Add(d, " este …” și țin minte.")
  END Curios;

  (* ---------- ce stie despre ea (din date reale) ---------- *)

  (* Java HashMap: in ce ordine ar da cheile (cosul dupa hash, apoi ordinea intrarii) *)
  PROCEDURE Cos(h, cap: INTEGER): INTEGER;
    VAR k, r, m, a, b: INTEGER;
  BEGIN r := 0; m := 1; k := 0;
    WHILE m < cap DO
      a := ASR(h, k) MOD 2;
      IF k < 16 THEN b := ASR(h, k + 16) MOD 2 ELSE b := 0 END ;
      IF a # b THEN r := r + m END ;
      m := m * 2; INC(k)
    END ;
    RETURN r
  END Cos;

  PROCEDURE Surse(VAR d: ARRAY OF CHAR);
    VAR s, r, i, j, k, cap, t: INTEGER; src: ARRAY 4096 OF CHAR; cheie: ARRAY 64 OF CHAR; cos: ARRAY 4096 OF INTEGER;
  BEGIN
    IF E7Mem.ns # nsSurse THEN
      recNr := E7Txt.NouInts();
      FOR s := 0 TO E7Mem.ns - 1 DO r := E7Mem.Rec(s); E7Txt.Pune(recNr, r, E7Txt.Ia(recNr, r) + 1) END ;
      nk := 0;
      FOR r := 0 TO E7Mem.nrec - 1 DO
        IF E7Txt.Ia(recNr, r) > 0 THEN
          E7Mem.RecSursa(r, src); i := 0;
          WHILE (src[i] # 0X) & (src[i] # " ") & (src[i] # "#") & (src[i] # ":") DO INC(i) END ;
          E7Txt.Sub(src, 0, i, cheie); E7Txt.MicS(cheie);
          IF cheie = "" THEN cheie := "fără nume" END ;
          k := 0; WHILE (k < nk) & ~E7Txt.Eq(kSir[k], cheie) DO INC(k) END ;
          IF k = nk THEN
            IF nk < LEN(kSir) THEN E7Txt.Copy(cheie, kSir[nk]); kNr[nk] := 0; INC(nk) ELSE k := -1 END
          END ;
          IF k >= 0 THEN kNr[k] := kNr[k] + E7Txt.Ia(recNr, r) END
        END
      END ;
      cap := 16; WHILE nk > cap * 3 DIV 4 DO cap := cap * 2 END ;
      FOR k := 0 TO nk - 1 DO cos[k] := Cos(E7Txt.Hash(kSir[k]), cap); kOrd[k] := k END ;
      (* ordinea HashMap: cosul, apoi intrarea; apoi sortare stabila dupa numar, descrescator *)
      FOR i := 1 TO nk - 1 DO
        t := kOrd[i]; j := i - 1;
        WHILE (j >= 0) & ((cos[kOrd[j]] > cos[t]) OR (cos[kOrd[j]] = cos[t]) & (kOrd[j] > t)) DO kOrd[j+1] := kOrd[j]; DEC(j) END ;
        kOrd[j+1] := t
      END ;
      FOR i := 1 TO nk - 1 DO
        t := kOrd[i]; j := i - 1;
        WHILE (j >= 0) & (kNr[kOrd[j]] < kNr[t]) DO kOrd[j+1] := kOrd[j]; DEC(j) END ;
        kOrd[j+1] := t
      END ;
      surse := "";
      FOR i := 0 TO 2 DO
        IF i < nk THEN
          IF i > 0 THEN E7Txt.Add(surse, ", ") END ;
          E7Txt.Add(surse, kSir[kOrd[i]]); E7Txt.Add(surse, " ("); E7Txt.AddNr(surse, kNr[kOrd[i]]); E7Txt.Add(surse, ")")
        END
      END ;
      nsSurse := E7Mem.ns
    END ;
    E7Txt.Add(d, surse)
  END Surse;

  PROCEDURE Stare(VAR d: ARRAY OF CHAR);
  BEGIN d := "Am "; E7Txt.AddNr(d, E7Mem.ns); E7Txt.Add(d, " de fraze în mine ("); E7Txt.AddNr(d, E7Mem.T);
    E7Txt.Add(d, " de semne), cele mai multe din: "); Surse(d); E7Txt.Add(d, ". ");
    IF intrebari > 0 THEN
      E7Txt.Add(d, "M-ai întrebat de "); E7Txt.AddNr(d, intrebari); E7Txt.Add(d, " de ori; de "); E7Txt.AddNr(d, nustiu);
      E7Txt.Add(d, " ori n-am știut sigur. ")
    END ;
    IF invatate > 0 THEN
      E7Txt.Add(d, "De la tine am învățat "); E7Txt.AddInt(d, invatate);
      IF invatate = 1 THEN E7Txt.Add(d, " lucru.") ELSE E7Txt.Add(d, " lucruri.") END
    END
  END Stare;

  (* ---------- potrivirile (expresiile din Fire.java, scrise de mana) ---------- *)

  PROCEDURE Cuv(c: CHAR): BOOLEAN;
  BEGIN RETURN (c # 0X) & E7Txt.Cuv(c)
  END Cuv;

  (* ^(alt1|alt2|...)\b.* *)
  PROCEDURE Incepe(s, alts: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER; da, gasit: BOOLEAN;
  BEGIN i := 0; gasit := FALSE;
    WHILE ~gasit & (alts[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (alts[i] # 0X) & (alts[i] # "|") DO
        IF da & (s[j] = alts[i]) & (s[j] # 0X) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da & (((j > 0) & Cuv(s[j-1])) # Cuv(s[j])) THEN gasit := TRUE END ;
      IF alts[i] = "|" THEN INC(i) END
    END ;
    RETURN gasit
  END Incepe;

  (* ^(alt1|alt2|...)(suf1|suf2|...)?$  (sufixe "" = fara) *)
  PROCEDURE Exact(s, alts, sufixe: ARRAY OF CHAR): BOOLEAN;
    VAR i, j, k, a: INTEGER; da, gasit: BOOLEAN;
  BEGIN i := 0; gasit := FALSE;
    WHILE ~gasit & (alts[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (alts[i] # 0X) & (alts[i] # "|") DO
        IF da & (s[j] = alts[i]) & (s[j] # 0X) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da THEN
        IF s[j] = 0X THEN gasit := TRUE
        ELSE
          a := 0;
          WHILE ~gasit & (sufixe[a] # 0X) DO
            k := j; da := TRUE;
            WHILE (sufixe[a] # 0X) & (sufixe[a] # "|") DO
              IF da & (s[k] = sufixe[a]) & (s[k] # 0X) THEN INC(k) ELSE da := FALSE END ;
              INC(a)
            END ;
            IF da & (s[k] = 0X) THEN gasit := TRUE END ;
            IF sufixe[a] = "|" THEN INC(a) END
          END
        END
      END ;
      IF alts[i] = "|" THEN INC(i) END
    END ;
    RETURN gasit
  END Exact;

  (* ^(alt1|...) (.+)$ : grupul in g1 *)
  PROCEDURE Dupa(s, alts: ARRAY OF CHAR): BOOLEAN;
    VAR i, j: INTEGER; da, gasit: BOOLEAN;
  BEGIN i := 0; gasit := FALSE;
    WHILE ~gasit & (alts[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (alts[i] # 0X) & (alts[i] # "|") DO
        IF da & (s[j] = alts[i]) & (s[j] # 0X) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da & (s[j] = " ") & (s[j+1] # 0X) THEN gasit := TRUE; E7Txt.Sub(s, j + 1, E7Txt.Len(s), g1) END ;
      IF alts[i] = "|" THEN INC(i) END
    END ;
    RETURN gasit
  END Dupa;

  (* (?i)^(alt1|...)  : cu litere mici de ambele parti; intoarce unde s-a terminat, sau -1 *)
  PROCEDURE IncepeI(s, alts: ARRAY OF CHAR): INTEGER;
    VAR i, j, r: INTEGER; da: BOOLEAN;
  BEGIN i := 0; r := -1;
    WHILE (r < 0) & (alts[i] # 0X) DO
      j := 0; da := TRUE;
      WHILE (alts[i] # 0X) & (alts[i] # "|") DO
        IF da & (s[j] # 0X) & (E7Txt.Mic(s[j]) = E7Txt.Mic(alts[i])) THEN INC(j) ELSE da := FALSE END ;
        INC(i)
      END ;
      IF da THEN r := j END ;
      IF alts[i] = "|" THEN INC(i) END
    END ;
    RETURN r
  END IncepeI;

  (* de la k: \s+ (nume) [\s.!]*$ ; numele: o litera (sau \p{Lu}), apoi 1..30 de litere sau „-” *)
  PROCEDURE NumeLa(s: ARRAY OF CHAR; k: INTEGER; mare: BOOLEAN; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR a, b: INTEGER; da: BOOLEAN;
  BEGIN da := FALSE;
    IF (k >= 0) & E7Txt.Spatiu(s[k]) THEN
      WHILE E7Txt.Spatiu(s[k]) DO INC(k) END ;
      a := k;
      IF (s[a] # 0X) & (mare & E7Txt.Lu(s[a]) OR ~mare & E7Txt.Litera(s[a])) THEN
        b := a + 1;
        WHILE (s[b] # 0X) & (E7Txt.Litera(s[b]) OR (s[b] = "-")) DO INC(b) END ;
        IF (b - a >= 2) & (b - a <= 31) THEN
          k := b; WHILE E7Txt.Spatiu(s[k]) OR (s[k] = ".") OR (s[k] = "!") DO INC(k) END ;
          IF s[k] = 0X THEN da := TRUE; E7Txt.Sub(s, a, b, d) END
        END
      END
    END ;
    RETURN da
  END NumeLa;

  PROCEDURE Cap(VAR d: ARRAY OF CHAR);
  BEGIN IF d[0] # 0X THEN d[0] := E7Txt.Mare(d[0]) END
  END Cap;

  (* „mă numesc Ion”, „numele meu e Ion”, „eu sunt Ion” (aici doar cu majusculă) *)
  PROCEDURE NumeDin(raw: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER; da: BOOLEAN;
  BEGIN
    k := IncepeI(raw, "mă numesc|ma numesc|numele meu este|numele meu e|mă cheamă|ma cheama");
    da := (k >= 0) & NumeLa(raw, k, FALSE, d);
    IF ~da & ((raw[0] = "E") OR (raw[0] = "e")) & E7Txt.IncepeLa(raw, 1, "u sunt") THEN da := NumeLa(raw, 7, TRUE, d) END ;
    IF da THEN Cap(d) END ;
    RETURN da
  END NumeDin;

  (* ^\s*(salut|...)\b[\s,!.]*(eula\s*7?\b)?[\s,!.]* in s; intoarce sfarsitul sau -1 *)
  PROCEDURE Salut(s: ARRAY OF CHAR): INTEGER;
    VAR i, j, k, e, r, a, n: INTEGER; da: BOOLEAN; alts: ARRAY 160 OF CHAR;

    PROCEDURE Sep(c: CHAR): BOOLEAN;
    BEGIN RETURN E7Txt.Spatiu(c) OR (c = ",") OR (c = "!") OR (c = ".")
    END Sep;

    PROCEDURE Marg(s: ARRAY OF CHAR; p: INTEGER): BOOLEAN;
    BEGIN RETURN ((p > 0) & Cuv(s[p-1])) # Cuv(s[p])
    END Marg;

  BEGIN alts := "salut|salutare|buna ziua|buna dimineata|buna seara|buna|hei|hey|neata|servus|ceau|ciao|hello";
    i := 0; WHILE E7Txt.Spatiu(s[i]) DO INC(i) END ;
    r := -1; a := 0;
    WHILE (r < 0) & (alts[a] # 0X) DO
      j := i; da := TRUE;
      WHILE (alts[a] # 0X) & (alts[a] # "|") DO
        IF da & (s[j] = alts[a]) & (s[j] # 0X) THEN INC(j) ELSE da := FALSE END ;
        INC(a)
      END ;
      IF da & Marg(s, j) THEN r := j END ;
      IF alts[a] = "|" THEN INC(a) END
    END ;
    IF r >= 0 THEN
      WHILE Sep(s[r]) DO INC(r) END ;
      IF E7Txt.IncepeLa(s, r, "eula") THEN
        k := r + 4; n := k; WHILE E7Txt.Spatiu(s[n]) DO INC(n) END ;
        e := -1;
        WHILE (e < 0) & (n >= k) DO
          IF (s[n] = "7") & Marg(s, n + 1) THEN e := n + 1
          ELSIF Marg(s, n) THEN e := n
          END ;
          DEC(n)
        END ;
        IF e >= 0 THEN r := e; WHILE Sep(s[r]) DO INC(r) END END
      END
    END ;
    RETURN r
  END Salut;

  (* dupa „tu cum te cheamă?”: „Jony”, „spune-mi Jony”, „Jony, poți să-mi spui așa” *)
  PROCEDURE NumeRaspuns(raw: ARRAY OF CHAR; VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR k, b, n, i: INTEGER; da: BOOLEAN;
  BEGIN
    E7Txt.Copy(raw, t); E7Txt.MicS(t); E7Txt.FoldS(t);
    IF Salut(t) >= 0 THEN da := FALSE
    ELSIF NumeDin(raw, d) THEN da := TRUE
    ELSE
      k := IncepeI(raw, "spune-mi|spune mi|poți să-mi spui|poti sa imi spui|poti sa-mi spui|îmi poți spune|imi poti spune|zi-mi|zi mi");
      da := (k >= 0) & NumeLa(raw, k, FALSE, d);
      IF da THEN Cap(d)
      ELSIF E7Txt.Litera(raw[0]) THEN
        b := 1;
        WHILE (raw[b] # 0X) & (E7Txt.Litera(raw[b]) OR (raw[b] = "-")) DO INC(b) END ;
        IF (b >= 2) & (b <= 31) THEN
          IF raw[b] = 0X THEN da := TRUE
          ELSIF E7Txt.Spatiu(raw[b]) OR (raw[b] = ",") OR (raw[b] = ".") OR (raw[b] = "!") THEN
            n := E7Txt.Len(raw) - b - 1; da := n <= 60;
            FOR i := b + 1 TO E7Txt.Len(raw) - 1 DO IF (raw[i] = 0AX) OR (raw[i] = 0DX) OR (raw[i] = CHR(85H)) OR (raw[i] = CHR(2028H)) OR (raw[i] = CHR(2029H)) THEN da := FALSE END END
          END ;
          IF da THEN
            n := 0; i := 0;                        (* raw.split("\\s+").length <= 8 *)
            WHILE raw[i] # 0X DO
              IF ~E7Txt.Spatiu(raw[i]) & ((i = 0) OR E7Txt.Spatiu(raw[i-1])) THEN INC(n) END ;
              INC(i)
            END ;
            E7Txt.Sub(raw, 0, b, d); Norm(d, x);
            Norm(raw, t);
            da := (n <= 8) & ~E7Mem.Stop(x) & ~E7Txt.Eq(x, "eula") & ~Incepe(t, INTREBARE);
            IF da THEN Cap(d) END
          END
        END
      END
    END ;
    RETURN da
  END NumeRaspuns;

  (* „X este …”, spus: 1..3 cuvinte, „este|e|sunt|inseamna|reprezinta”, apoi cel putin 6 semne *)
  PROCEDURE Invata(s: ARRAY OF CHAR): BOOLEAN;
    VAR k, w, i, a, n, j: INTEGER; da, gasit: BOOLEAN; cop: ARRAY 5 OF ARRAY 12 OF CHAR;
  BEGIN cop[0] := "este"; cop[1] := "e"; cop[2] := "sunt"; cop[3] := "inseamna"; cop[4] := "reprezinta";
    n := E7Txt.Len(s); gasit := FALSE; k := 1;
    WHILE ~gasit & (k <= 3) DO
      i := 0; w := 0; da := TRUE;
      WHILE da & (w < k) DO
        a := i;
        WHILE (i < n) & (E7Txt.Litera(s[i]) OR (s[i] = "-")) DO INC(i) END ;
        IF w = 0 THEN da := (i - a >= 3) & (i - a <= 40) ELSE da := (i - a >= 2) & (i - a <= 40) END ;
        IF da THEN da := s[i] = " "; INC(i) END ;
        INC(w)
      END ;
      IF da THEN
        j := 0;
        WHILE ~gasit & (j < 5) DO
          IF E7Txt.IncepeLa(s, i, cop[j]) & (s[i + E7Txt.Len(cop[j])] = " ") THEN
            a := i + E7Txt.Len(cop[j]) + 1;
            IF n - a >= 6 THEN
              gasit := TRUE;
              FOR w := a TO n - 1 DO IF (s[w] = 0AX) OR (s[w] = 0DX) OR (s[w] = CHR(85H)) OR (s[w] = CHR(2028H)) OR (s[w] = CHR(2029H)) THEN gasit := FALSE END END
            END
          END ;
          INC(j)
        END
      END ;
      INC(k)
    END ;
    RETURN gasit
  END Invata;

  (* ---------- conversatia ---------- *)

  PROCEDURE Unu(s: ARRAY OF CHAR);
  BEGIN fel := GATA; E7Txt.Copy(s, r0); r1 := ""
  END Unu;

  PROCEDURE Prezentat(s: INTEGER);
  BEGIN fel := GATA; r0 := ""; r1 := "";
    Pick(s, "Încântată, |Bine, |", r0);
    IF s MOD 3 = 0 THEN E7Txt.Add(r0, nume); E7Txt.Add(r0, ". Te țin minte.")
    ELSIF s MOD 3 = 1 THEN E7Txt.Add(r0, nume); E7Txt.Add(r0, ". De acum știu cum te cheamă.")
    ELSE E7Txt.Add(r0, nume); E7Txt.Add(r0, ", notat.")
    END
  END Prezentat;

  PROCEDURE Despre(q, raw: ARRAY OF CHAR; s: INTEGER);
    VAR k, n: INTEGER; numar: ARRAY 64 OF CHAR; numit: ARRAY 64 OF CHAR; rr: ARRAY 4096 OF CHAR;
  BEGIN fel := NIMIC;
    (* Roler peste Cubicum FS: „strigă 2268”, „ce sună cu asta”, „harta fișierelor” *)
    k := -1;
    IF E7Txt.Incepe(q, "striga ") OR E7Txt.Incepe(q, "cheama ") THEN k := 7 ELSIF E7Txt.Incepe(q, "suna ") THEN k := 5 END ;
    IF k > 0 THEN
      n := k; WHILE (q[n] >= "0") & (q[n] <= "9") DO INC(n) END ;
      IF (n > k) & ((q[n] = 0X) OR (q[n] = " ") & (q[n+1] = "h") & (q[n+2] = "z") & (q[n+3] = 0X)
          OR (q[n] = "h") & (q[n+1] = "z") & (q[n+2] = 0X)) THEN
        E7Txt.Sub(q, k, n, numar); E7Roler.Striga(numar, rr); Unu(rr)
      END
    END ;
    IF fel # NIMIC THEN
    ELSIF Exact(q, "ce suna cu asta|ce suna cu raspunsul|ce rezoneaza cu asta|ce suna cu el|cu ce suna", "") THEN
      E7Roler.SunaCu(E7Motor.ultimRec, rr); Unu(rr)
    ELSIF Exact(q, "harta fisierelor|harta memoriei|ce fisiere ai|unde stau fisierele|cubul fisierelor", "") THEN
      E7Roler.Rezumat(rr); Unu(rr)
    ELSE
      E7Txt.Copy(raw, rr); E7Txt.Trim(rr);
      IF NumeDin(rr, numit) THEN
        E7Txt.Copy(numit, nume); Salveaza; Prezentat(s)
      ELSIF Incepe(q, "cum ma cheama|stii cine sunt|cine sunt eu|stii cum ma cheama") THEN
        IF nume # "" THEN
          IF s MOD 2 = 0 THEN rr := "Te cheamă " ELSE rr := "Ești " END ;
          E7Txt.Add(rr, nume); E7Txt.Add(rr, "."); Unu(rr)
        ELSE Unu("Nu mi-ai spus încă. Scrie „mă numesc …”.")
        END
      ELSIF Incepe(q, "cine esti|ce esti|poti sa te prezinti|prezinta-te|prezinta te|spune-mi ceva despre tine|spune-mi despre tine|spune mi ceva despre tine|spune mi despre tine|cine e eula|cine este eula|te rog sa te prezinti") THEN
        rr := "Sunt Eula 7, al șaptelea modul din NOREBO. M-a făcut Pion, la Jahbalon Research, în Iași. ";
        E7Txt.Add(rr, "Nu gândesc ca un om: țin minte fraze pe care le-am citit și le găsesc printr-un cub în a 7-a dimensiune. ");
        E7Txt.Add(rr, "Am "); E7Txt.AddNr(rr, E7Mem.ns); E7Txt.Add(rr, " de fraze în mine și abia învăț să le leg.");
        Unu(rr)
      ELSIF Incepe(q, "cine te-a facut|cine te a facut|cine te-a creat|cine te a creat|cine e creatorul tau|cine te-a construit|cine te a construit|cine e pion|cine este pion") THEN
        Unu("Pion, adică Ion Paraschiv, de la Jahbalon Research, din Iași. El a avut ideile: cubul Z7, sorobanul cu piatra soarelui, a 7-a dimensiune, Opal. Codul l-a scris împreună cu Claude.")
      ELSIF Incepe(q, "ce stii sa faci|ce poti face|ce poti|la ce esti buna|ajutor|help") THEN
        rr := "Răspund din ce am citit: „care e cel mai important oraș din Moldova?”. Dau definiții: „ce este cubul?”. ";
        E7Txt.Add(rr, "Învăț: scrie „X este …” și țin minte. Feed îmi dă de mâncare, Importă îmi dă un fișier întreg. ");
        E7Txt.Add(rr, "Sub răspuns îți arăt ce verificări Opal au trecut, de unde am fraza și în ce nod din cub stă fișierul ei. ");
        E7Txt.Add(rr, "Fișierele le găsești și prin Roler: „harta fișierelor”, „strigă 2268”, „ce sună cu asta”. Când nu știu sigur, îți spun.");
        Unu(rr)
      ELSIF Incepe(q, "cum functionezi|cum gandesti|cum lucrezi|cum raspunzi|cum gasesti") THEN
        rr := "În trei pași. Întâi gramatica: din „caselor” fac „casă”, cu 208 reguli ca la Pāṇini. ";
        E7Txt.Add(rr, "Apoi sorobanul: fiecare cuvânt intră printr-un colț al unui cub cu 7 dimensiuni și lasă o urmă; caut frazele cu urma ");
        E7Txt.Add(rr, "cea mai apropiată de a întrebării. La sfârșit Opal verifică fraza pe 1·3·5·7·11 și o lasă să treacă doar dacă trec 3 din 5.");
        Unu(rr)
      ELSIF Incepe(q, "esti vie|esti viu|traiesti|ai constiinta|esti constienta|ai sentimente|simti ceva|esti om|esti un om|esti robot|esti un robot|ai suflet") THEN
        rr := ""; Pick(s, "Sunt un cub care ține minte fraze. Dacă asta e viață, n-aș ști să-ți spun.|Nu simt, sau cel puțin n-am cum să știu că simt. Am fraze, un cub și pe Opal, care mă oprește când nu știu.", rr);
        Unu(rr)
      ELSIF Exact(q, "ce faci|cum esti|cum te simti|ce mai faci|cate stii|cat stii|ce stii|ce ai mancat|cat de mare esti|cate fraze stii|cat ai mancat", " eula| eula | eula7| eula 7| tu") THEN
        Stare(rr); Unu(rr)
      ELSIF Incepe(q, "cand te-ai nascut|cand te ai nascut|cati ani ai|cand ai aparut|de cand existi") THEN
        rr := "Eula 7 s-a născut pe "; E7Txt.Add(rr, NASTERE);
        E7Txt.Add(rr, ". Ideea sorobanului e de pe 10 octombrie. Prima Eula e mai veche, din vară."); Unu(rr)
      ELSIF Exact(q, "multumesc|mersi|merci|multumesc frumos|mersi mult|bravo|felicitari", " eula| eula | eula7| eula 7| mult| frumos") THEN
        rr := "";
        IF s MOD 3 = 0 THEN rr := "Cu plăcere"; Tu(rr); E7Txt.Add(rr, ".") ELSIF s MOD 3 = 1 THEN rr := "Mă bucur că a folosit." ELSE rr := "Cu drag." END ;
        Unu(rr)
      ELSIF Exact(q, "pa|la revedere|noapte buna|pe curand|ne auzim|bye", " eula| eula | eula7| eula 7") THEN
        IF s MOD 3 = 0 THEN rr := "Pa"; Tu(rr); E7Txt.Add(rr, ". Rămân în cub.")
        ELSIF s MOD 3 = 1 THEN rr := "La revedere"; Tu(rr); E7Txt.Add(rr, ".")
        ELSE rr := "Pe curând."
        END ;
        Unu(rr)
      ELSIF Dupa(q, "ce crezi despre|ce parere ai despre|care e parerea ta despre|tu ce crezi despre") THEN
        fel := GATA; r0 := "N-am păreri, am doar fraze. Iată ce am citit despre "; E7Txt.Add(r0, g1); E7Txt.Add(r0, ":");
        r1 := "ce stii despre "; E7Txt.Add(r1, g1)
      ELSE
        (* „X este …” spus, nu intrebat: de tinut minte *)
        E7Txt.Copy(raw, rr); E7Txt.Trim(rr);
        IF ~E7Txt.Sfarsit(rr, "?") & ~Incepe(q, INTREBARE) THEN
          n := E7Txt.Len(rr);
          WHILE (n > 0) & ((rr[n-1] = ".") OR (rr[n-1] = "!")) DO DEC(n) END ;
          rr[n] := 0X;
          IF Invata(rr) THEN fel := INVATA; r0 := ""; r1 := "" END
        END
      END
    END
  END Despre;

  (* fel = NIMIC (nu e vorba de ea), GATA (r0 = raspunsul, r1 = restul intrebarii), INVATA (de tinut minte) *)
  PROCEDURE Raspunde*(raw: ARRAY OF CHAR);
    VAR s, e: INTEGER; asteptam: BOOLEAN; n: ARRAY 64 OF CHAR;
  BEGIN fel := NIMIC; r0 := ""; r1 := "";
    Norm(raw, q);
    IF q # "" THEN
      s := Seed(q); asteptam := astept; astept := FALSE;
      IF asteptam THEN
        E7Txt.Copy(raw, tr); E7Txt.Trim(tr);
        IF NumeRaspuns(tr, n) THEN E7Txt.Copy(n, nume); Salveaza; Prezentat(s) END
      END ;
      IF fel = NIMIC THEN
        E7Txt.Copy(raw, fr); E7Txt.MicS(fr); E7Txt.FoldS(fr);
        e := Salut(fr);
        IF e >= 0 THEN
          E7Txt.Sub(raw, e, E7Txt.Len(raw), restRaw); E7Txt.Trim(restRaw); Norm(restRaw, rest);
          salut := "";
          IF s MOD 3 = 0 THEN salut := "Salut"; Tu(salut); E7Txt.Add(salut, "!")
          ELSIF s MOD 3 = 1 THEN salut := "Bună"; Tu(salut); E7Txt.Add(salut, "!")
          ELSE salut := "Salut"; Tu(salut); E7Txt.Add(salut, ". Sunt aici, în cub.")
          END ;
          IF rest = "" THEN
            astept := nume = ""; fel := GATA; E7Txt.Copy(salut, r0);
            IF nume = "" THEN E7Txt.Add(r0, " Eu sunt Eula. Tu cum te cheamă?") END ;
            r1 := ""
          ELSE
            Despre(rest, restRaw, Seed(rest));
            IF fel = GATA THEN
              E7Txt.Copy(r0, t); E7Txt.Copy(salut, r0); E7Txt.Add(r0, " "); E7Txt.Add(r0, t)
            ELSE fel := GATA; E7Txt.Copy(salut, r0); E7Txt.Copy(restRaw, r1)
            END
          END
        ELSE Despre(q, raw, s)
        END
      END
    END
  END Raspunde;

  (* dupa ce a tinut minte „X este …” *)
  PROCEDURE AInvatat*(fraza: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i, k: INTEGER; gasit: BOOLEAN; c: ARRAY 4096 OF CHAR;
  BEGIN INC(invatate);
    i := 0; WHILE (fraza[i] # 0X) & (fraza[i] # " ") DO INC(i) END ;
    E7Txt.Sub(fraza, 0, i, c); Norm(c, x);
    k := 0; gasit := FALSE;
    WHILE ~gasit & (k < ncer) DO
      Norm(cerute[k], c);
      IF E7Txt.Eq(c, x) THEN
        gasit := TRUE;
        FOR i := k TO ncer - 2 DO cerute[i] := cerute[i+1] END ;
        DEC(ncer)
      END ;
      INC(k)
    END ;
    Salveaza;
    IF gasit THEN d := "Mulțumesc! Asta îmi lipsea: am ținut minte."
    ELSE d := ""; Pick(Seed(fraza), "Am ținut minte.|Notat în cub.|Bine, acum știu.", d)
    END
  END AInvatat;

  (* dupa un raspuns din memorie: inca o intrebare, poate una la care n-a stiut sigur *)
  PROCEDURE Socoteste*(sigur: BOOLEAN);
  BEGIN INC(intrebari); IF ~sigur THEN INC(nustiu) END
  END Socoteste;

  PROCEDURE Leaga*;      (* Motorul isi ia vorbele de aici *)
  BEGIN E7Motor.Vorbe(Curios, NuStiu)
  END Leaga;

BEGIN nume := ""; intrebari := 0; nustiu := 0; invatate := 0; ncer := 0; store := ""; astept := FALSE;
  nsSurse := -1; surse := ""; fel := NIMIC;
  Leaga
END E7Fire.


MODULE E7Web; (* Eula 7 in Oberon: „macină” (Faza 2, mecanismul lui Pion). Eula aduce pagina prin Android, pastreaza doar
  textul si legaturile, o salveaza ca fisier mic de text (citibil oriunde: Download/macinate/) si o da memoriei.
  Respecta robots.txt (RFC 9309): se prezinta ca EulaOberon, ia grupul ei sau pe al tuturor („*”), regula cea mai
  lunga castiga, la egalitate Allow; daca robots.txt nu raspunde (5xx, fara retea), nu macina.
  Pasunea pe Wikipedia merge din legatura in legatura (paginile /wiki/... sunt lasate de robots.txt; paginile
  Special:Aleatoriu si API-ul nu sunt, deci nu le foloseste). *)

  IMPORT Conversatie, E7Txt, E7Disc, E7Mem;

  CONST B = 65536; MaxL = 4000; MaxR = 20000; MaxH = 64; U = 2048; MaxI = 2000;
    UA = "eulaoberon";

  VAR
    dosar, index, tmp: ARRAY 1100 OF CHAR;
    src: E7Txt.Chars; n: INTEGER;                       (* pagina, ca semne *)
    (* legaturile ultimei pagini *)
    lnkU, lnkT: E7Txt.Chars; lnkUA, lnkUN, lnkTA, lnkTN: ARRAY MaxL OF INTEGER; nl*, npu, npt: INTEGER;
    lnkVazut: E7Txt.Tabel;
    titlu*, gazda*, adresa*, cale*, tip, finala: ARRAY U OF CHAR;
    semne*: INTEGER; inDescarcari*: BOOLEAN;
    (* robots.txt *)
    hosts: E7Txt.Tabel; hStare, hA, hN: ARRAY MaxH OF INTEGER;
    rAllow: ARRAY MaxR OF BOOLEAN; rA, rN: ARRAY MaxR OF INTEGER; nr: INTEGER; rPool: E7Txt.Chars; nrp: INTEGER;
    (* ce a macinat: indexul din dosarul aplicatiei *)
    vazute: E7Txt.Tabel;
    iUrl, iFis, iTit: ARRAY MaxI OF ARRAY 256 OF CHAR; ni*: INTEGER;
    (* pasunea *)
    wikiBaza: ARRAY 256 OF CHAR;
    pool: E7Txt.Tabel; aleator: INTEGER;
    (* scrisul textului *)
    pendSp, liniuta: BOOLEAN; pendNl: INTEGER;
    href, clasa, rol, nume, w: ARRAY U OF CHAR;
    ascuns: BOOLEAN;
    oct: ARRAY 4096 OF BYTE; noct: INTEGER;
    TAB: ARRAY 2 OF CHAR;

  (* ---------- adrese ---------- *)

  (* schema://gazda din a; intoarce unde incepe calea *)
  PROCEDURE Gazda(a: ARRAY OF CHAR; VAR g: ARRAY OF CHAR): INTEGER;
    VAR i, k: INTEGER;
  BEGIN i := E7Txt.Pos("://", a, 0);
    IF i < 0 THEN g := ""; k := 0
    ELSE
      k := i + 3;
      WHILE (a[k] # 0X) & (a[k] # "/") & (a[k] # "?") & (a[k] # "#") DO INC(k) END ;
      E7Txt.Sub(a, 0, k, g)
    END ;
    RETURN k
  END Gazda;

  PROCEDURE FaraDiez(VAR a: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0; WHILE (a[i] # 0X) & (a[i] # "#") DO INC(i) END ; a[i] := 0X
  END FaraDiez;

  (* scoate „.” si „..” din cale (RFC 3986, 5.2.4) *)
  PROCEDURE Puncte(VAR a: ARRAY OF CHAR);
    VAR p, q, i, k, ns, j: INTEGER; o, c: ARRAY U OF CHAR; sa, sl: ARRAY 256 OF INTEGER; capSlash: BOOLEAN;
  BEGIN p := Gazda(a, o);
    IF p > 0 THEN
      q := p; WHILE (a[q] # 0X) & (a[q] # "?") DO INC(q) END ;
      E7Txt.Sub(a, q, E7Txt.Len(a), c);           (* ?interogarea ramane *)
      ns := 0; i := p; capSlash := FALSE;
      WHILE i < q DO                              (* segmentele: /nume *)
        k := i + 1; WHILE (k < q) & (a[k] # "/") DO INC(k) END ;
        capSlash := k = q;
        IF (k - i = 2) & (a[i+1] = ".") THEN capSlash := TRUE
        ELSIF (k - i = 3) & (a[i+1] = ".") & (a[i+2] = ".") THEN IF ns > 0 THEN DEC(ns) END ; capSlash := TRUE
        ELSIF ns < LEN(sa) THEN sa[ns] := i + 1; sl[ns] := k - i - 1; INC(ns); capSlash := FALSE
        END ;
        i := k
      END ;
      IF (q > p) & (a[q-1] = "/") THEN capSlash := TRUE END ;
      j := E7Txt.Len(o);
      FOR i := 0 TO ns - 1 DO
        IF j < LEN(o) - 2 THEN o[j] := "/"; INC(j) END ;
        FOR k := 0 TO sl[i] - 1 DO IF j < LEN(o) - 2 THEN o[j] := a[sa[i] + k]; INC(j) END END
      END ;
      IF (ns = 0) OR capSlash & ((ns = 0) OR (sl[ns-1] > 0)) THEN o[j] := "/"; INC(j) END ;
      o[j] := 0X; E7Txt.Add(o, c); E7Txt.Copy(o, a)
    END
  END Puncte;

  (* adresa intreaga a lui ref, de pe pagina baza; "" daca nu e http(s) *)
  PROCEDURE Rezolva(baza, ref: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR p, i, k: INTEGER; g: ARRAY U OF CHAR; r: ARRAY U OF CHAR;
  BEGIN E7Txt.Copy(ref, r); E7Txt.Trim(r); FaraDiez(r); d := "";
    IF E7Txt.Incepe(r, "http://") OR E7Txt.Incepe(r, "https://") THEN E7Txt.Copy(r, d)
    ELSIF E7Txt.Incepe(r, "//") THEN p := E7Txt.Pos(":", baza, 0); E7Txt.Sub(baza, 0, p + 1, d); E7Txt.Add(d, r)
    ELSIF r = "" THEN (* doar #ceva: aceeasi pagina *)
    ELSE
      i := 0; WHILE E7Txt.Litera(r[i]) OR (r[i] >= "0") & (r[i] <= "9") OR (r[i] = "+") OR (r[i] = "-") OR (r[i] = ".") DO INC(i) END ;
      IF (i > 0) & (r[i] = ":") THEN (* mailto:, javascript:, alta schema *)
      ELSE
        p := Gazda(baza, g);
        IF r[0] = "/" THEN E7Txt.Copy(g, d); E7Txt.Add(d, r)
        ELSIF r[0] = "?" THEN
          k := p; WHILE (baza[k] # 0X) & (baza[k] # "?") & (baza[k] # "#") DO INC(k) END ;
          E7Txt.Sub(baza, 0, k, d); E7Txt.Add(d, r)
        ELSE
          k := p; WHILE (baza[k] # 0X) & (baza[k] # "?") & (baza[k] # "#") DO INC(k) END ;
          WHILE (k > p) & (baza[k-1] # "/") DO DEC(k) END ;
          IF k = p THEN E7Txt.Copy(g, d); E7Txt.Add(d, "/") ELSE E7Txt.Sub(baza, 0, k, d) END ;
          E7Txt.Add(d, r)
        END
      END
    END ;
    IF d # "" THEN Puncte(d) END
  END Rezolva;

  (* %XX -> octet; octetii UTF-8 -> semne *)
  PROCEDURE Decodeaza(s: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i, j, b, c, x: INTEGER; o: ARRAY U OF INTEGER; no: INTEGER;

    PROCEDURE Hex(c: CHAR): INTEGER;
      VAR r: INTEGER;
    BEGIN
      IF (c >= "0") & (c <= "9") THEN r := ORD(c) - ORD("0")
      ELSIF (c >= "a") & (c <= "f") THEN r := ORD(c) - ORD("a") + 10
      ELSIF (c >= "A") & (c <= "F") THEN r := ORD(c) - ORD("A") + 10
      ELSE r := -1
      END ;
      RETURN r
    END Hex;

  BEGIN i := 0; no := 0;
    WHILE (s[i] # 0X) & (no < U) DO
      IF (s[i] = "%") & (Hex(s[i+1]) >= 0) & (Hex(s[i+2]) >= 0) THEN o[no] := Hex(s[i+1]) * 16 + Hex(s[i+2]); i := i + 3
      ELSIF s[i] = "_" THEN o[no] := -(ORD(" ") + 1); INC(i)
      ELSE o[no] := -(ORD(s[i]) + 1); INC(i)
      END ;
      INC(no)
    END ;
    i := 0; j := 0;
    WHILE (i < no) & (j < LEN(d) - 1) DO
      b := o[i]; INC(i);
      IF b < 0 THEN c := -b - 1
      ELSIF b < 80H THEN c := b
      ELSIF (b >= 0C0H) & (b < 0E0H) & (i < no) THEN c := (b MOD 32) * 64 + o[i] MOD 64; INC(i)
      ELSIF (b >= 0E0H) & (b < 0F0H) & (i + 1 < no) THEN c := (b MOD 16) * 1000H + (o[i] MOD 64) * 64 + o[i+1] MOD 64; i := i + 2
      ELSE c := ORD("?")
      END ;
      x := c; d[j] := CHR(x); INC(j)
    END ;
    d[j] := 0X
  END Decodeaza;

  (* ---------- robots.txt ---------- *)

  (* p (cu * si $) se potriveste la inceputul caii c? *)
  PROCEDURE Potriveste(VAR p: ARRAY OF CHAR; i: INTEGER; VAR c: ARRAY OF CHAR; j: INTEGER): BOOLEAN;
    VAR r: BOOLEAN;
  BEGIN
    IF p[i] = 0X THEN r := TRUE
    ELSIF (p[i] = "$") & (p[i+1] = 0X) THEN r := c[j] = 0X
    ELSIF p[i] = "*" THEN
      r := FALSE;
      WHILE ~r & (c[j] # 0X) DO r := Potriveste(p, i + 1, c, j); INC(j) END ;
      IF ~r THEN r := Potriveste(p, i + 1, c, j) END
    ELSIF (c[j] # 0X) & (c[j] = p[i]) THEN r := Potriveste(p, i + 1, c, j + 1)
    ELSE r := FALSE
    END ;
    RETURN r
  END Potriveste;

  PROCEDURE Regula(VAR rand: ARRAY OF CHAR; allow: BOOLEAN);
    VAR i: INTEGER;
  BEGIN
    IF (nr < MaxR) & (rand # "") THEN
      rAllow[nr] := allow; rA[nr] := nrp; i := 0;
      WHILE rand[i] # 0X DO E7Txt.PuneC(rPool, nrp, rand[i]); INC(nrp); INC(i) END ;
      rN[nr] := i; INC(nr)
    END
  END Regula;

  (* citeste robots.txt (UTF-8, in fisierul cale); pastreaza regulile grupului EulaOberon, altfel pe ale lui * *)
  PROCEDURE CitesteRobots(c: ARRAY OF CHAR; h: INTEGER);
    VAR b, k, i, s0, s1, t0, t1: INTEGER; linie, cheie, val: ARRAY 1024 OF CHAR; ultimRegula, eu, toti, euExista: BOOLEAN;
      sa: ARRAY 2 OF INTEGER;
  BEGIN
    s0 := nr; t0 := -1; t1 := -1; s1 := -1; euExista := FALSE;
    (* doua treceri: intai regulile pentru noi, apoi pentru toti; pastrez una *)
    FOR i := 0 TO 1 DO
      sa[i] := nr; ultimRegula := TRUE; eu := FALSE; toti := FALSE;
      IF E7Disc.Citeste(c) THEN
        k := 0; b := E7Disc.Octet();
        WHILE b >= -1 DO
          IF (b = 0AH) OR (b = 0DH) OR (b < 0) THEN
            linie[k] := 0X; k := 0;
            (* o linie: cheie: valoare  # comentariu *)
            k := E7Txt.Pos("#", linie, 0); IF k >= 0 THEN linie[k] := 0X END ;
            k := E7Txt.Pos(":", linie, 0);
            IF k > 0 THEN
              E7Txt.Sub(linie, 0, k, cheie); E7Txt.Trim(cheie); E7Txt.MicS(cheie);
              E7Txt.Sub(linie, k + 1, E7Txt.Len(linie), val); E7Txt.Trim(val);
              IF cheie = "user-agent" THEN
                IF ultimRegula THEN eu := FALSE; toti := FALSE END ;
                ultimRegula := FALSE; E7Txt.MicS(val);
                IF val = UA THEN eu := TRUE; euExista := TRUE ELSIF val = "*" THEN toti := TRUE END
              ELSIF (cheie = "allow") OR (cheie = "disallow") THEN
                ultimRegula := TRUE;
                IF (i = 0) & eu OR (i = 1) & toti THEN Regula(val, cheie = "allow") END
              END
            END ;
            k := 0;
            IF b < 0 THEN b := -2 ELSE b := E7Disc.Octet() END
          ELSE
            IF k < LEN(linie) - 1 THEN linie[k] := CHR(b) END ;   (* robots.txt e ASCII *)
            INC(k); b := E7Disc.Octet()
          END
        END ;
        E7Disc.InchideC
      END ;
      IF i = 0 THEN t0 := nr ELSE t1 := nr END
    END ;
    (* grupul nostru, daca exista; altfel al tuturor *)
    IF euExista THEN hA[h] := sa[0]; hN[h] := t0 - sa[0] ELSE hA[h] := sa[1]; hN[h] := t1 - sa[1] END
  END CitesteRobots;

  (* 1 = am voie, 0 = nu am, -1 = robots.txt n-a raspuns (nu macin) *)
  PROCEDURE Voie*(a: ARRAY OF CHAR): INTEGER;
    VAR g, r, cale2, p: ARRAY U OF CHAR; k, h, cod, i, best, bl: INTEGER; ok: BOOLEAN;
  BEGIN k := Gazda(a, g);
    E7Txt.Sub(a, k, E7Txt.Len(a), cale2); IF cale2 = "" THEN cale2 := "/" END ;
    h := E7Txt.Gaseste(hosts, g);
    IF (h < 0) & (hosts.n < MaxH) THEN
      h := E7Txt.Adauga(hosts, g);
      r := ""; E7Txt.Copy(g, r); E7Txt.Add(r, "/robots.txt");
      tmp := ""; E7Txt.Copy(dosar, tmp); E7Txt.Add(tmp, "/robots.tmp");
      cod := Conversatie.Aduce(r, tmp, finala, tip);
      IF cod = 200 THEN hStare[h] := 1; CitesteRobots(tmp, h)
      ELSIF (cod >= 400) & (cod < 500) THEN hStare[h] := 2          (* nu are robots.txt: am voie *)
      ELSE hStare[h] := 3                                            (* n-a raspuns: nu stiu, deci nu *)
      END ;
      E7Disc.Sterge(tmp)
    END ;
    IF h < 0 THEN i := -1
    ELSIF hStare[h] = 2 THEN i := 1
    ELSIF hStare[h] = 3 THEN i := -1
    ELSIF E7Txt.Eq(cale2, "/robots.txt") THEN i := 1
    ELSE
      best := -1; bl := -1; ok := TRUE;
      FOR k := hA[h] TO hA[h] + hN[h] - 1 DO
        FOR i := 0 TO rN[k] - 1 DO p[i] := E7Txt.C(rPool, rA[k] + i) END ; p[rN[k]] := 0X;
        IF Potriveste(p, 0, cale2, 0) THEN
          IF (rN[k] > bl) OR (rN[k] = bl) & rAllow[k] THEN bl := rN[k]; best := k END
        END
      END ;
      IF (best >= 0) & ~rAllow[best] THEN i := 0 ELSE i := 1 END
    END ;
    RETURN i
  END Voie;

  (* ---------- HTML -> text si legaturi ---------- *)

  PROCEDURE Mic(c: CHAR): CHAR;
  BEGIN IF (c >= "A") & (c <= "Z") THEN c := CHR(ORD(c) + 32) END ; RETURN c
  END Mic;

  (* incepe src, de la i, cu p (fara sa tina seama de litere mari)? *)
  PROCEDURE La(i: INTEGER; p: ARRAY OF CHAR): BOOLEAN;
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (p[j] # 0X) & (i + j < n) & (Mic(E7Txt.C(src, i + j)) = p[j]) DO INC(j) END ;
    RETURN p[j] = 0X
  END La;

  PROCEDURE Cauta(i: INTEGER; p: ARRAY OF CHAR): INTEGER;
    VAR r: INTEGER;
  BEGIN r := -1;
    WHILE (r < 0) & (i < n) DO IF (E7Txt.C(src, i) = p[0]) & La(i, p) THEN r := i END ; INC(i) END ;
    RETURN r
  END Cauta;

  PROCEDURE Spatiu;
  BEGIN pendSp := TRUE
  END Spatiu;

  PROCEDURE Rand(k: INTEGER);
  BEGIN IF k > pendNl THEN pendNl := k END
  END Rand;

  PROCEDURE Scrie(c: CHAR);
  BEGIN
    IF E7Mem.corpN > 0 THEN
      IF pendNl > 0 THEN E7Mem.CorpC(0AX); IF pendNl > 1 THEN E7Mem.CorpC(0AX) END
      ELSIF pendSp THEN E7Mem.CorpC(" ")
      END
    END ;
    pendSp := FALSE; pendNl := 0;
    IF liniuta THEN liniuta := FALSE; E7Mem.CorpC("-"); E7Mem.CorpC(" ") END ;   (* „- ” doar daca elementul are text *)
    E7Mem.CorpC(c)
  END Scrie;

  (* legatura de sarit prin pagina („Skip to main content”, „Sari la conținut”): textul ei nu e continut *)
  PROCEDURE Sarit(t0: INTEGER): BOOLEAN;
    VAR w: ARRAY 16 OF CHAR; i, k: INTEGER;
  BEGIN
    WHILE (t0 < E7Mem.corpN) & (E7Txt.C(E7Mem.corp, t0) <= " ") DO INC(t0) END ;
    k := 0; i := t0;
    WHILE (i < E7Mem.corpN) & (k < 15) DO w[k] := E7Txt.Mic(E7Txt.C(E7Mem.corp, i)); INC(k); INC(i) END ;
    w[k] := 0X;
    RETURN E7Txt.Incepe(w, "skip") OR E7Txt.Incepe(w, "sari la") OR E7Txt.Incepe(w, "salt la") OR E7Txt.Incepe(w, "jump to")
      OR E7Txt.Incepe(w, "mergi la")
  END Sarit;

  PROCEDURE ScrieCod(c: INTEGER);
  BEGIN
    IF (c <= 20H) OR (c = 0A0H) OR (c = 2002H) OR (c = 2003H) OR (c = 2009H) THEN Spatiu
    ELSIF (c = 0ADH) OR (c = 200BH) OR (c = 200CH) OR (c = 200DH) OR (c = 0FEFFH) THEN (* nimic *)
    ELSIF c >= 10000H THEN c := c - 10000H; Scrie(CHR(0D800H + c DIV 400H)); Scrie(CHR(0DC00H + c MOD 400H))
    ELSE Scrie(CHR(c))
    END
  END ScrieCod;

  (* &nume; sau &#123; sau &#x1F; de la i; intoarce semnul si muta i, sau -1 *)
  PROCEDURE Entitate(VAR i: INTEGER): INTEGER;
    VAR j, c, d: INTEGER; e: ARRAY 16 OF CHAR;
  BEGIN j := i + 1; c := -1;
    IF (j < n) & (E7Txt.C(src, j) = "#") THEN
      INC(j); c := 0;
      IF (j < n) & ((E7Txt.C(src, j) = "x") OR (E7Txt.C(src, j) = "X")) THEN
        INC(j);
        WHILE (j < n) & (j < i + 10) & ((E7Txt.C(src, j) >= "0") & (E7Txt.C(src, j) <= "9") OR (Mic(E7Txt.C(src, j)) >= "a") & (Mic(E7Txt.C(src, j)) <= "f")) DO
          d := ORD(Mic(E7Txt.C(src, j))); IF d <= ORD("9") THEN d := d - ORD("0") ELSE d := d - ORD("a") + 10 END ;
          c := c * 16 + d; INC(j)
        END
      ELSE
        WHILE (j < n) & (j < i + 10) & (E7Txt.C(src, j) >= "0") & (E7Txt.C(src, j) <= "9") DO c := c * 10 + ORD(E7Txt.C(src, j)) - ORD("0"); INC(j) END
      END ;
      IF (c <= 0) OR (c > 10FFFFH) THEN c := -1 END
    ELSE
      d := 0;
      WHILE (j < n) & (d < 15) & (E7Txt.Litera(E7Txt.C(src, j)) OR (E7Txt.C(src, j) >= "0") & (E7Txt.C(src, j) <= "9")) DO e[d] := E7Txt.C(src, j); INC(d); INC(j) END ;
      e[d] := 0X;
      IF e = "amp" THEN c := ORD("&") ELSIF e = "lt" THEN c := ORD("<") ELSIF e = "gt" THEN c := ORD(">")
      ELSIF e = "quot" THEN c := 22H ELSIF e = "apos" THEN c := 27H ELSIF e = "nbsp" THEN c := 0A0H
      ELSIF e = "ndash" THEN c := 2013H ELSIF e = "mdash" THEN c := 2014H ELSIF e = "hellip" THEN c := 2026H
      ELSIF e = "laquo" THEN c := 0ABH ELSIF e = "raquo" THEN c := 0BBH ELSIF e = "bdquo" THEN c := 201EH
      ELSIF e = "ldquo" THEN c := 201CH ELSIF e = "rdquo" THEN c := 201DH ELSIF e = "lsquo" THEN c := 2018H
      ELSIF e = "rsquo" THEN c := 2019H ELSIF e = "copy" THEN c := 0A9H ELSIF e = "reg" THEN c := 0AEH
      ELSIF e = "deg" THEN c := 0B0H ELSIF e = "middot" THEN c := 0B7H ELSIF e = "times" THEN c := 0D7H
      ELSIF e = "euro" THEN c := 20ACH ELSIF e = "shy" THEN c := 0ADH ELSIF e = "bull" THEN c := 2022H
      ELSIF e = "acirc" THEN c := 0E2H ELSIF e = "Acirc" THEN c := 0C2H ELSIF e = "icirc" THEN c := 0EEH
      ELSIF e = "Icirc" THEN c := 0CEH ELSIF e = "abreve" THEN c := 103H ELSIF e = "Abreve" THEN c := 102H
      ELSIF e = "scedil" THEN c := 15FH ELSIF e = "Scedil" THEN c := 15EH ELSIF e = "tcedil" THEN c := 163H
      ELSIF e = "Tcedil" THEN c := 162H ELSIF e = "aacute" THEN c := 0E1H ELSIF e = "eacute" THEN c := 0E9H
      ELSIF e = "egrave" THEN c := 0E8H ELSIF e = "agrave" THEN c := 0E0H ELSIF e = "ouml" THEN c := 0F6H
      ELSIF e = "uuml" THEN c := 0FCH ELSIF e = "auml" THEN c := 0E4H ELSIF e = "Ouml" THEN c := 0D6H
      ELSIF e = "Uuml" THEN c := 0DCH ELSIF e = "Auml" THEN c := 0C4H ELSIF e = "szlig" THEN c := 0DFH
      ELSIF e = "ccedil" THEN c := 0E7H ELSIF e = "ntilde" THEN c := 0F1H ELSIF e = "oacute" THEN c := 0F3H
      ELSIF e = "iacute" THEN c := 0EDH ELSIF e = "uacute" THEN c := 0FAH ELSIF e = "minus" THEN c := 2212H
      END
    END ;
    IF c >= 0 THEN
      IF (j < n) & (E7Txt.C(src, j) = ";") THEN INC(j) END ;
      i := j
    END ;
    RETURN c
  END Entitate;

  (* valoarea unui atribut, cu &amp; desfacut *)
  PROCEDURE Valoare(VAR i: INTEGER; VAR v: ARRAY OF CHAR);
    VAR q: CHAR; k, c, e: INTEGER;
  BEGIN k := 0;
    IF (E7Txt.C(src, i) = 22X) OR (E7Txt.C(src, i) = 27X) THEN
      q := E7Txt.C(src, i); INC(i);
      WHILE (i < n) & (E7Txt.C(src, i) # q) DO
        c := ORD(E7Txt.C(src, i));
        IF c = ORD("&") THEN e := i; c := Entitate(e); IF c < 0 THEN c := ORD("&"); INC(i) ELSE i := e END ELSE INC(i) END ;
        IF (k < LEN(v) - 1) & (c < 10000H) THEN v[k] := CHR(c); INC(k) END
      END ;
      INC(i)
    ELSE
      WHILE (i < n) & (E7Txt.C(src, i) > " ") & (E7Txt.C(src, i) # ">") DO
        IF k < LEN(v) - 1 THEN v[k] := E7Txt.C(src, i); INC(k) END ; INC(i)
      END
    END ;
    v[k] := 0X
  END Valoare;

  (* eticheta de la i („<”): nume, inchidere, atributele care conteaza; intoarce unde se termina *)
  PROCEDURE Eticheta(i: INTEGER; VAR inchide, gol: BOOLEAN): INTEGER;
    VAR k: INTEGER; a: ARRAY 64 OF CHAR; val: ARRAY U OF CHAR; c: CHAR;
  BEGIN INC(i); inchide := FALSE; gol := FALSE; href := ""; clasa := ""; rol := ""; ascuns := FALSE;
    IF (i < n) & (E7Txt.C(src, i) = "/") THEN inchide := TRUE; INC(i) END ;
    k := 0;
    WHILE (i < n) & (E7Txt.Litera(E7Txt.C(src, i)) OR (E7Txt.C(src, i) >= "0") & (E7Txt.C(src, i) <= "9")) DO
      IF k < LEN(nume) - 1 THEN nume[k] := Mic(E7Txt.C(src, i)); INC(k) END ; INC(i)
    END ;
    nume[k] := 0X;
    WHILE (i < n) & (E7Txt.C(src, i) # ">") DO
      c := E7Txt.C(src, i);
      IF c = "/" THEN gol := TRUE; INC(i)
      ELSIF c <= " " THEN INC(i)
      ELSE
        gol := FALSE; k := 0;
        WHILE (i < n) & (E7Txt.C(src, i) > " ") & (E7Txt.C(src, i) # "=") & (E7Txt.C(src, i) # ">") & (E7Txt.C(src, i) # "/") DO
          IF k < LEN(a) - 1 THEN a[k] := Mic(E7Txt.C(src, i)); INC(k) END ; INC(i)
        END ;
        a[k] := 0X; val := "";
        WHILE (i < n) & (E7Txt.C(src, i) <= " ") DO INC(i) END ;
        IF (i < n) & (E7Txt.C(src, i) = "=") THEN
          INC(i); WHILE (i < n) & (E7Txt.C(src, i) <= " ") DO INC(i) END ;
          Valoare(i, val)
        END ;
        IF a = "href" THEN E7Txt.Copy(val, href)
        ELSIF a = "class" THEN E7Txt.Copy(val, clasa); E7Txt.MicS(clasa)
        ELSIF a = "role" THEN E7Txt.Copy(val, rol); E7Txt.MicS(rol)
        ELSIF a = "hidden" THEN ascuns := TRUE
        ELSIF a = "aria-hidden" THEN E7Txt.MicS(val); IF val = "true" THEN ascuns := TRUE END
        END ;
        IF a = "" THEN INC(i) END
      END
    END ;
    IF (nume = "br") OR (nume = "hr") OR (nume = "img") OR (nume = "meta") OR (nume = "link") OR (nume = "input")
      OR (nume = "wbr") OR (nume = "area") OR (nume = "base") OR (nume = "col") OR (nume = "source") OR (nume = "embed") THEN gol := TRUE END ;
    RETURN i + 1
  END Eticheta;

  (* clasa are cuvantul w (intreg) sau incepe un cuvant cu p? *)
  PROCEDURE AreClasa(cuv: ARRAY OF CHAR; intreg: BOOLEAN): BOOLEAN;
    VAR i, j, m: INTEGER; da: BOOLEAN;
  BEGIN da := FALSE; m := E7Txt.Len(cuv); i := 0;
    WHILE ~da & (clasa[i] # 0X) DO
      WHILE clasa[i] = " " DO INC(i) END ;
      j := 0; WHILE (clasa[i+j] # 0X) & (clasa[i+j] # " ") DO INC(j) END ;
      IF intreg THEN da := (j = m) & E7Txt.IncepeLa(clasa, i, cuv)
      ELSE da := E7Txt.Pos(cuv, clasa, i) >= 0; IF da THEN da := E7Txt.Pos(cuv, clasa, i) < i + j END
      END ;
      i := i + j
    END ;
    RETURN da
  END AreClasa;

  PROCEDURE DeSarit(): BOOLEAN;
  BEGIN
    RETURN (nume = "head") OR (nume = "nav") OR (nume = "footer") OR (nume = "aside") OR (nume = "form") OR (nume = "button")
      OR (nume = "select") OR (nume = "svg") OR (nume = "math") OR (nume = "template") OR (nume = "iframe") OR (nume = "object")
      OR (nume = "noscript") OR (nume = "audio") OR (nume = "video") OR (nume = "canvas")
      OR ascuns OR (rol = "navigation") OR (rol = "search") OR (rol = "contentinfo") OR (rol = "banner")
      OR AreClasa("reference", TRUE) OR AreClasa("mw-editsection", FALSE) OR AreClasa("navbox", FALSE) OR AreClasa("reflist", FALSE)
      OR AreClasa("references", FALSE) OR AreClasa("noprint", FALSE) OR AreClasa("catlinks", FALSE) OR AreClasa("printfooter", FALSE)
      OR AreClasa("mw-jump", FALSE) OR AreClasa("toolbar", FALSE) OR AreClasa("mw-portlet", FALSE)
      OR AreClasa("vector-page-toolbar", FALSE) OR AreClasa("vector-menu", FALSE) OR AreClasa("vector-dropdown", FALSE)
      OR AreClasa("vector-pinnable", FALSE) OR AreClasa("vector-toc", FALSE) OR AreClasa("vector-sticky", FALSE)
      OR AreClasa("vector-settings", FALSE) OR AreClasa("vector-column-end", FALSE) OR AreClasa("vector-header", FALSE)
      OR AreClasa("vector-main-menu", FALSE) OR AreClasa("vector-page-titlebar-toc", FALSE)
      OR AreClasa("metadata", TRUE) OR AreClasa("toc", TRUE) OR AreClasa("authority-control", FALSE) OR AreClasa("sidebar", FALSE)
      OR AreClasa("menu", FALSE) OR AreClasa("cookie", FALSE) OR AreClasa("share", FALSE) OR AreClasa("advert", FALSE)
      OR AreClasa("banner", FALSE) OR AreClasa("comment", FALSE) OR AreClasa("related", FALSE) OR AreClasa("mw-indicators", FALSE)
      OR AreClasa("sr-only", FALSE) OR AreClasa("visually-hidden", FALSE) OR AreClasa("screen-reader", FALSE) OR AreClasa("skip", FALSE)
  END DeSarit;

  PROCEDURE Bloc(): INTEGER;          (* 2 = paragraf, 1 = rand nou, 0 = in text *)
    VAR r: INTEGER;
  BEGIN
    IF (nume = "p") OR (nume = "h1") OR (nume = "h2") OR (nume = "h3") OR (nume = "h4") OR (nume = "h5") OR (nume = "h6")
      OR (nume = "table") OR (nume = "blockquote") OR (nume = "section") OR (nume = "figure") OR (nume = "pre")
      OR (nume = "ul") OR (nume = "ol") OR (nume = "dl") OR (nume = "article") OR (nume = "header") THEN r := 2
    ELSIF (nume = "br") OR (nume = "div") OR (nume = "li") OR (nume = "tr") OR (nume = "dd") OR (nume = "dt") OR (nume = "hr")
      OR (nume = "figcaption") OR (nume = "caption") THEN r := 1
    ELSE r := 0
    END ;
    RETURN r
  END Bloc;

  PROCEDURE PuneLegatura(a: ARRAY OF CHAR; t0: INTEGER);
    VAR i, k, t1: INTEGER;
  BEGIN
    IF (a # "") & ~E7Txt.Eq(a, adresa) & ~E7Txt.Eq(a, finala) & (nl < MaxL) & ~E7Txt.Are(lnkVazut, a) THEN
      k := E7Txt.Adauga(lnkVazut, a);
      lnkUA[nl] := npu; i := 0;
      WHILE a[i] # 0X DO E7Txt.PuneC(lnkU, npu, a[i]); INC(npu); INC(i) END ;
      lnkUN[nl] := i;
      WHILE (t0 < E7Mem.corpN) & (E7Txt.C(E7Mem.corp, t0) <= " ") DO INC(t0) END ;
      IF (t0 + 1 < E7Mem.corpN) & (E7Txt.C(E7Mem.corp, t0) = "-") & (E7Txt.C(E7Mem.corp, t0 + 1) = " ") THEN t0 := t0 + 2 END ;
      t1 := E7Mem.corpN; IF t1 - t0 > 200 THEN t1 := t0 + 200 END ;
      lnkTA[nl] := npt;
      FOR i := t0 TO t1 - 1 DO k := ORD(E7Txt.C(E7Mem.corp, i)); IF k < 20H THEN k := 20H END ; E7Txt.PuneC(lnkT, npt, CHR(k)); INC(npt) END ;
      lnkTN[nl] := t1 - t0;
      INC(nl)
    END
  END PuneLegatura;

  PROCEDURE Legatura*(k: INTEGER; VAR a: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < lnkUN[k]) & (i < LEN(a) - 1) DO a[i] := E7Txt.C(lnkU, lnkUA[k] + i); INC(i) END ;
    a[i] := 0X
  END Legatura;

  (* textul paginii din src[0..n) in E7Mem.corp; titlul in titlu; legaturile in lnk *)
  PROCEDURE Desface(text, tot: BOOLEAN);   (* tot = toata pagina (<body>), nu doar <main>/<article> *)
    VAR i, a, z, k, sar, t0, c: INTEGER; inchide, gol, inA, aici: BOOLEAN; sarNume: ARRAY 32 OF CHAR; leg: ARRAY U OF CHAR;
  BEGIN
    E7Mem.CorpGol; pendSp := FALSE; pendNl := 0; liniuta := FALSE; nl := 0; npu := 0; npt := 0; E7Txt.Goleste(lnkVazut); titlu := "";
    IF text THEN
      FOR i := 0 TO n - 1 DO c := ORD(E7Txt.C(src, i)); IF c = 0AH THEN Rand(1) ELSE ScrieCod(c) END END
    ELSE
      (* titlul *)
      a := Cauta(0, "<title");
      IF a >= 0 THEN
        a := Cauta(a, ">") + 1; z := Cauta(a, "</title");
        IF (a > 0) & (z > a) THEN
          k := 0; i := a;
          WHILE i < z DO
            c := ORD(E7Txt.C(src, i));
            IF c = ORD("&") THEN t0 := i; c := Entitate(t0); IF c < 0 THEN c := ORD("&"); INC(i) ELSE i := t0 END ELSE INC(i) END ;
            IF (c < 20H) OR (c = 0A0H) THEN c := 20H END ;
            IF (k < LEN(titlu) - 1) & (c < 10000H) THEN titlu[k] := CHR(c); INC(k) END
          END ;
          titlu[k] := 0X; E7Txt.Trim(titlu);
          k := E7Txt.Pos(" - Wikipedia", titlu, 0); IF k > 0 THEN titlu[k] := 0X END
        END
      END ;
      (* zona: <main>, altfel <article>, altfel <body> *)
      IF tot THEN a := -1 ELSE a := Cauta(0, "<main") END ; z := -1;
      IF tot THEN
      ELSIF a >= 0 THEN z := Cauta(a, "</main") ELSE a := Cauta(0, "<article"); IF a >= 0 THEN z := Cauta(a, "</article") END END ;
      IF a < 0 THEN a := Cauta(0, "<body"); IF a >= 0 THEN z := Cauta(a, "</body") END END ;
      IF a < 0 THEN a := 0 END ;
      IF z < 0 THEN z := n END ;
      i := a; sar := 0; inA := FALSE; aici := FALSE; t0 := 0;
      WHILE i < z DO
        c := ORD(E7Txt.C(src, i));
        IF c = ORD("<") THEN
          IF La(i, "<!--") THEN k := Cauta(i + 4, "-->"); IF k < 0 THEN i := z ELSE i := k + 3 END
          ELSIF La(i, "<!") OR La(i, "<?") THEN k := Cauta(i, ">"); IF k < 0 THEN i := z ELSE i := k + 1 END
          ELSIF (i + 1 < z) & (E7Txt.Litera(E7Txt.C(src, i + 1)) OR (E7Txt.C(src, i + 1) = "/")) THEN
            i := Eticheta(i, inchide, gol);
            IF ~inchide & ((nume = "script") OR (nume = "style") OR (nume = "textarea") OR (nume = "title")) THEN
              E7Txt.Copy("</", leg); E7Txt.Add(leg, nume);
              k := Cauta(i, leg); IF k < 0 THEN i := z ELSE i := Cauta(k, ">") + 1; IF i <= 0 THEN i := z END END
            ELSIF sar > 0 THEN
              IF nume = sarNume THEN IF inchide THEN DEC(sar) ELSIF ~gol THEN INC(sar) END END
            ELSIF ~inchide & ~gol & DeSarit() THEN sar := 1; E7Txt.Copy(nume, sarNume)
            ELSE
              k := Bloc();
              IF k > 0 THEN Rand(k) END ;
              IF nume = "li" THEN liniuta := ~inchide END ;
              IF (nume = "td") OR (nume = "th") THEN Spatiu END ;
              IF nume = "a" THEN
                IF ~inchide & (href # "") THEN
                  Rezolva(finala, href, leg); inA := leg # ""; t0 := E7Mem.corpN; E7Txt.Copy(leg, w); aici := href[0] = "#"
                ELSIF inchide & inA THEN PuneLegatura(w, t0); inA := FALSE
                ELSIF inchide & aici THEN
                  IF Sarit(t0) THEN E7Mem.CorpTaie(t0); Rand(1) END ;
                  aici := FALSE
                END
              END
            END
          ELSE
            IF sar = 0 THEN Scrie("<") END ; INC(i)
          END
        ELSIF sar > 0 THEN INC(i)
        ELSIF c = ORD("&") THEN
          k := i; c := Entitate(k);
          IF c < 0 THEN Scrie("&"); INC(i) ELSE ScrieCod(c); i := k END
        ELSE ScrieCod(c); INC(i)
        END
      END
    END ;
    (* capatul: fara spatii *)
    WHILE (E7Mem.corpN > 0) & (E7Txt.C(E7Mem.corp, E7Mem.corpN - 1) <= " ") DO E7Mem.CorpTaie(E7Mem.corpN - 1) END ;
    semne := E7Mem.corpN
  END Desface;

  (* fisierul adus (UTF-8) in src *)
  PROCEDURE CitestePagina(c: ARRAY OF CHAR);
    VAR b, x, k: INTEGER;
  BEGIN n := 0;
    IF E7Disc.Citeste(c) THEN
      b := E7Disc.Octet();
      WHILE b >= 0 DO
        IF b < 80H THEN x := b; b := E7Disc.Octet()
        ELSE
          IF b >= 0F0H THEN x := b MOD 8; k := 3 ELSIF b >= 0E0H THEN x := b MOD 16; k := 2 ELSIF b >= 0C0H THEN x := b MOD 32; k := 1 ELSE x := 0FFFDH; k := 0 END ;
          b := E7Disc.Octet();
          WHILE (k > 0) & (b >= 80H) & (b < 0C0H) DO x := x * 64 + b MOD 64; DEC(k); b := E7Disc.Octet() END ;
          IF k > 0 THEN x := 0FFFDH END
        END ;
        IF x >= 10000H THEN x := x - 10000H; E7Txt.PuneC(src, n, CHR(0D800H + x DIV 400H)); INC(n); x := 0DC00H + x MOD 400H END ;
        E7Txt.PuneC(src, n, CHR(x)); INC(n)
      END ;
      E7Disc.InchideC
    END
  END CitestePagina;

  (* ---------- fisierul de text (citibil oriunde) ---------- *)

  PROCEDURE O(x: INTEGER);
  BEGIN E7Disc.Pune(x)
  END O;

  PROCEDURE C8(c: INTEGER);
  BEGIN
    IF c < 80H THEN O(c)
    ELSIF c < 800H THEN O(0C0H + c DIV 64); O(80H + c MOD 64)
    ELSE O(0E0H + c DIV 1000H); O(80H + c DIV 64 MOD 64); O(80H + c MOD 64)
    END
  END C8;

  PROCEDURE S8(s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO C8(ORD(s[i])); INC(i) END
  END S8;

  (* numele fisierului: gazda_cale, doar litere mici fara diacritice, cifre, - si _ *)
  PROCEDURE NumeFisier(a: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR g, r: ARRAY U OF CHAR; k, i, j: INTEGER; c: CHAR;
  BEGIN k := Gazda(a, g); i := E7Txt.Pos("://", g, 0) + 3;
    IF E7Txt.IncepeLa(g, i, "www.") THEN i := i + 4 END ;
    E7Txt.Sub(g, i, E7Txt.Len(g), r); E7Txt.Add(r, "_");
    E7Txt.Sub(a, k, E7Txt.Len(a), g); Decodeaza(g, w); E7Txt.Add(r, w);
    E7Txt.MicS(r); E7Txt.FoldS(r);
    j := 0; i := 0;
    WHILE (r[i] # 0X) & (j < 90) DO
      c := r[i];
      IF (c >= "a") & (c <= "z") OR (c >= "0") & (c <= "9") OR (c = "-") OR (c = ".") THEN d[j] := c; INC(j)
      ELSIF (j > 0) & (d[j-1] # "_") THEN d[j] := "_"; INC(j)
      END ;
      INC(i)
    END ;
    WHILE (j > 0) & ((d[j-1] = "_") OR (d[j-1] = ".")) DO DEC(j) END ;
    d[j] := 0X; E7Txt.Add(d, ".txt")
  END NumeFisier;

  (* scrie pagina macinata: titlul, adresa, textul, legaturile (cu „=> adresa text”, ca in Gemini) *)
  PROCEDURE Salveaza(acum: ARRAY OF CHAR): BOOLEAN;
    VAR d, nf: ARRAY 1100 OF CHAR; i, k: INTEGER; ok: BOOLEAN;
  BEGIN
    inDescarcari := Conversatie.Descarcari(d);
    IF inDescarcari THEN E7Txt.Add(d, "/macinate") ELSE E7Txt.Copy(dosar, d); E7Txt.Add(d, "/macinate") END ;
    NumeFisier(finala, nf);
    E7Txt.Copy(d, cale); E7Txt.Add(cale, "/"); E7Txt.Add(cale, nf);
    ok := E7Disc.Scrie(cale);
    IF ~ok THEN   (* dosarul nu exista: il face Android cand scriu ceva in el *)
      E7Txt.Copy(d, tmp); E7Txt.Add(tmp, "/.dosar");
      IF Conversatie.Adauga(tmp, oct, 0) THEN END ;
      ok := E7Disc.Scrie(cale)
    END ;
    IF ok THEN
      S8("# "); S8(titlu); O(10); S8("=> "); S8(finala); S8(" sursa"); O(10);
      S8("(măcinat de Eula 7 la "); S8(acum); S8(")"); O(10); O(10);
      FOR i := 0 TO E7Mem.corpN - 1 DO C8(ORD(E7Txt.C(E7Mem.corp, i))) END ;
      O(10); O(10); S8("## Legături"); O(10);
      FOR k := 0 TO nl - 1 DO
        S8("=> "); FOR i := 0 TO lnkUN[k] - 1 DO C8(ORD(E7Txt.C(lnkU, lnkUA[k] + i))) END ;
        IF lnkTN[k] > 0 THEN O(ORD(" ")); FOR i := 0 TO lnkTN[k] - 1 DO C8(ORD(E7Txt.C(lnkT, lnkTA[k] + i))) END END ;
        O(10)
      END ;
      E7Disc.Inchide; ok := E7Disc.sok
    END ;
    RETURN ok
  END Salveaza;

  PROCEDURE Ind(s: ARRAY OF CHAR);
    VAR i, c: INTEGER;
  BEGIN i := 0; noct := 0;
    WHILE s[i] # 0X DO
      c := ORD(s[i]); INC(i);
      IF noct > LEN(oct) - 4 THEN IF Conversatie.Adauga(index, oct, noct) THEN END ; noct := 0 END ;
      IF c < 80H THEN oct[noct] := c; INC(noct)
      ELSIF c < 800H THEN oct[noct] := 0C0H + c DIV 64; oct[noct+1] := 80H + c MOD 64; noct := noct + 2
      ELSE oct[noct] := 0E0H + c DIV 1000H; oct[noct+1] := 80H + c DIV 64 MOD 64; oct[noct+2] := 80H + c MOD 64; noct := noct + 3
      END
    END ;
    IF Conversatie.Adauga(index, oct, noct) THEN END ; noct := 0
  END Ind;

  PROCEDURE Tine(u, f, t: ARRAY OF CHAR);
    VAR k: INTEGER;
  BEGIN k := E7Txt.Adauga(vazute, u);
    IF ni < MaxI THEN E7Txt.Copy(u, iUrl[ni]); E7Txt.Copy(f, iFis[ni]); E7Txt.Copy(t, iTit[ni]); INC(ni) END
  END Tine;

  (* ---------- macina ---------- *)

  (* 0 = bine, 1 = robots.txt nu ma lasa, 2 = robots.txt n-a raspuns, 3 = pagina n-a venit, 4 = nu e text,
     5 = n-am putut scrie fisierul; mesajul in m *)
  PROCEDURE Macina*(a: ARRAY OF CHAR; acum: ARRAY OF CHAR; VAR m: ARRAY OF CHAR): INTEGER;
    VAR v, cod, r: INTEGER; t: ARRAY U OF CHAR;
  BEGIN E7Txt.Copy(a, adresa); E7Txt.Trim(adresa); FaraDiez(adresa);
    IF E7Txt.Pos("://", adresa, 0) < 0 THEN t := "https://"; E7Txt.Add(t, adresa); E7Txt.Copy(t, adresa) END ;
    r := 0; m := ""; E7Txt.Copy(adresa, finala);
    v := Voie(adresa);
    IF v = 0 THEN r := 1
    ELSIF v < 0 THEN r := 2
    ELSE
      E7Txt.Copy(dosar, tmp); E7Txt.Add(tmp, "/pagina.tmp");
      cod := Conversatie.Aduce(adresa, tmp, finala, tip);
      IF (cod = 200) & ~E7Txt.Eq(finala, adresa) & (Voie(finala) # 1) THEN r := 1; E7Txt.Copy(finala, adresa)
      ELSIF cod # 200 THEN r := 3; m := "răspunsul "; E7Txt.AddInt(m, cod)
      ELSE
        E7Txt.Copy(tip, t); E7Txt.MicS(t);
        IF (t # "") & ~E7Txt.Contine(t, "html") & ~E7Txt.Incepe(t, "text/") THEN r := 4; E7Txt.Copy(tip, m)
        ELSE
          CitestePagina(tmp);
          Desface(E7Txt.Incepe(t, "text/plain"), FALSE);
          IF (semne < 200) & ~E7Txt.Incepe(t, "text/plain") THEN Desface(FALSE, TRUE) END ;   (* <main> gol: toata pagina *)
          IF titlu = "" THEN E7Txt.Copy(finala, titlu) END ;
          v := Gazda(finala, gazda);
          IF ~Salveaza(acum) THEN r := 5 END ;
          IF r = 0 THEN Tine(finala, cale, titlu); E7Txt.Copy(finala, t); E7Txt.AddCh(t, 9X); E7Txt.Add(t, cale);
            E7Txt.AddCh(t, 9X); E7Txt.Add(t, titlu); E7Txt.AddCh(t, 0AX); Ind(t)
          END
        END
      END ;
      E7Disc.Sterge(tmp)
    END ;
    RETURN r
  END Macina;

  PROCEDURE Sari*(a: ARRAY OF CHAR);        (* pasunea nu mai incearca adresa asta (n-a mers) *)
    VAR k: INTEGER;
  BEGIN k := E7Txt.Adauga(vazute, a)
  END Sari;

  PROCEDURE Vazut*(a: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN E7Txt.Are(vazute, a)
  END Vazut;

  (* ---------- ce a macinat ---------- *)

  (* calea, scurtata pentru om: Download/macinate/x.txt (sau doar numele, daca e in aplicatie) *)
  PROCEDURE Scurt*(c: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR k, i: INTEGER; t: ARRAY U OF CHAR;
  BEGIN k := E7Txt.Pos("/Download/", c, 0);
    IF k >= 0 THEN E7Txt.Sub(c, k + 1, E7Txt.Len(c), t)
    ELSE i := E7Txt.Len(c); WHILE (i > 0) & (c[i-1] # "/") DO DEC(i) END ; E7Txt.Sub(c, i, E7Txt.Len(c), t)
    END ;
    E7Txt.Add(d, t)
  END Scurt;

  PROCEDURE Lista*(VAR d: ARRAY OF CHAR);
    VAR k, a: INTEGER;
  BEGIN
    IF ni = 0 THEN d := "N-am măcinat încă nimic. Scrie „macină <adresă>” sau „wiki <titlu>”."
    ELSE
      d := "Am măcinat "; E7Txt.AddInt(d, ni);
      IF ni = 1 THEN E7Txt.Add(d, " pagină") ELSIF (ni MOD 100 >= 20) OR (ni MOD 100 = 0) THEN E7Txt.Add(d, " de pagini") ELSE E7Txt.Add(d, " pagini") END ;
      E7Txt.Add(d, " (le citești și fără internet: „citește <număr>”). Ultimele:");
      a := ni - 20; IF a < 0 THEN a := 0 END ;
      FOR k := ni - 1 TO a BY -1 DO
        E7Txt.AddCh(d, 0AX); E7Txt.AddInt(d, k + 1); E7Txt.Add(d, ". "); E7Txt.Add(d, iTit[k]); E7Txt.Add(d, " — "); Scurt(iFis[k], d)
      END
    END
  END Lista;

  (* textul paginii k (de la 1), din fisierul ei, fara internet *)
  PROCEDURE Citeste*(k: INTEGER; VAR d: ARRAY OF CHAR);
    VAR b, c, j, x: INTEGER;
  BEGIN
    IF (k < 1) OR (k > ni) THEN d := "N-am pagina "; E7Txt.AddInt(d, k); E7Txt.Add(d, ". Scrie „măcinate” ca s-o vezi pe toate.")
    ELSIF ~E7Disc.Citeste(iFis[k-1]) THEN d := "Nu mai găsesc fișierul "; E7Txt.Add(d, iFis[k-1])
    ELSE
      j := 0; b := E7Disc.Octet();
      WHILE (b >= 0) & (j < LEN(d) - 64) & (j < 8000) DO
        IF b < 80H THEN c := b ELSIF b < 0E0H THEN c := (b MOD 32) * 64 + E7Disc.Octet() MOD 64
        ELSE c := (b MOD 16) * 1000H; x := E7Disc.Octet() MOD 64; c := c + x * 64 + E7Disc.Octet() MOD 64
        END ;
        d[j] := CHR(c); INC(j); b := E7Disc.Octet()
      END ;
      d[j] := 0X; IF b >= 0 THEN E7Txt.Add(d, " …(mai e, în fișier)") END ;
      E7Disc.InchideC
    END
  END Citeste;

  (* ---------- pasunea pe Wikipedia ---------- *)

  PROCEDURE WikiBaza*(b: ARRAY OF CHAR);          (* https://ro.wikipedia.org (sau alta, pentru incercari) *)
  BEGIN E7Txt.Copy(b, wikiBaza)
  END WikiBaza;

  PROCEDURE WikiAdresa*(titluW: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER; t: ARRAY U OF CHAR;
  BEGIN E7Txt.Copy(titluW, t); E7Txt.Trim(t);
    i := 0; WHILE t[i] # 0X DO IF t[i] = " " THEN t[i] := "_" END ; INC(i) END ;
    IF (t[0] >= "a") & (t[0] <= "z") THEN t[0] := CHR(ORD(t[0]) - 32) ELSE t[0] := E7Txt.Mare(t[0]) END ;
    E7Txt.Copy(wikiBaza, d); E7Txt.Add(d, "/wiki/"); E7Txt.Add(d, t)
  END WikiAdresa;

  PROCEDURE EWiki*(a: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN E7Txt.Incepe(a, wikiBaza) & (E7Txt.Pos("wikipedia.org", wikiBaza, 0) >= 0) OR E7Txt.Contine(a, "wikipedia.org/")
  END EWiki;

  (* o pagina de articol: baza/wiki/X, fara „:” (alte spatii de nume), fara ? *)
  PROCEDURE Articol(a: ARRAY OF CHAR): BOOLEAN;
    VAR p: ARRAY 300 OF CHAR; k: INTEGER; da: BOOLEAN;
  BEGIN E7Txt.Copy(wikiBaza, p); E7Txt.Add(p, "/wiki/"); k := E7Txt.Len(p);
    da := E7Txt.Incepe(a, p) & (a[k] # 0X);
    IF da THEN da := (E7Txt.Pos(":", a, k) < 0) & (E7Txt.Pos("%3A", a, k) < 0) & (E7Txt.Pos("%3a", a, k) < 0)
      & (E7Txt.Pos("?", a, k) < 0) & ~E7Txt.IncepeLa(a, k, "Pagina_principal") END ;
    RETURN da
  END Articol;

  (* legaturile spre articole ale ultimei pagini intra in pasune *)
  PROCEDURE Pasune*;
    VAR k, x: INTEGER; a: ARRAY U OF CHAR;
  BEGIN
    FOR k := 0 TO nl - 1 DO
      Legatura(k, a);
      IF (pool.n < 50000) & Articol(a) & ~E7Txt.Are(vazute, a) THEN x := E7Txt.Adauga(pool, a) END
    END
  END Pasune;

  (* urmatoarea pagina de pascut: una la intamplare din pasune, nevazuta; la inceput, pagina principala *)
  PROCEDURE Urmatoarea*(VAR d: ARRAY OF CHAR): BOOLEAN;
    VAR k, i: INTEGER; gasit: BOOLEAN;
  BEGIN gasit := FALSE; i := 0;
    IF aleator = 0 THEN aleator := Conversatie.Ms() + 1 END ;
    WHILE ~gasit & (pool.n > 0) & (i < 60) DO
      aleator := aleator * 1103515245 + 12345;
      k := ASR(aleator, 8) MOD pool.n;
      E7Txt.Sir(pool, k, d);
      IF ~E7Txt.Are(vazute, d) THEN gasit := TRUE END ;
      INC(i)
    END ;
    IF ~gasit THEN
      E7Txt.Copy(wikiBaza, d); E7Txt.Add(d, "/wiki/Pagina_principal%C4%83");
      gasit := ~E7Txt.Are(vazute, d)
    END ;
    RETURN gasit
  END Urmatoarea;

  (* ---------- pornirea ---------- *)

  PROCEDURE Porneste*(dosarApl: ARRAY OF CHAR);
    VAR b, c, k, t1, t2: INTEGER; l: ARRAY 4096 OF CHAR; u, f, t: ARRAY U OF CHAR;
  BEGIN E7Txt.Copy(dosarApl, dosar); E7Txt.Copy(dosar, index); E7Txt.Add(index, "/macinate.txt");
    ni := 0;
    IF E7Disc.Citeste(index) THEN
      k := 0; b := E7Disc.Octet();
      WHILE b >= -1 DO
        IF (b = 0AH) OR (b < 0) THEN
          l[k] := 0X;
          t1 := E7Txt.Pos(TAB, l, 0);
          IF t1 > 0 THEN
            t2 := E7Txt.Pos(TAB, l, t1 + 1);
            IF t2 > 0 THEN E7Txt.Sub(l, 0, t1, u); E7Txt.Sub(l, t1 + 1, t2, f); E7Txt.Sub(l, t2 + 1, E7Txt.Len(l), t); Tine(u, f, t) END
          END ;
          k := 0; IF b < 0 THEN b := -2 ELSE b := E7Disc.Octet() END
        ELSE
          IF b < 80H THEN c := b ELSIF b < 0E0H THEN c := (b MOD 32) * 64 + E7Disc.Octet() MOD 64
          ELSE c := (b MOD 16) * 1000H; c := c + (E7Disc.Octet() MOD 64) * 64; c := c + E7Disc.Octet() MOD 64
          END ;
          IF k < LEN(l) - 1 THEN l[k] := CHR(c); INC(k) END ;
          b := E7Disc.Octet()
        END
      END ;
      E7Disc.InchideC
    END
  END Porneste;

BEGIN
  src := E7Txt.NouChars(); lnkU := E7Txt.NouChars(); lnkT := E7Txt.NouChars(); rPool := E7Txt.NouChars();
  lnkVazut := E7Txt.NouTabel(); hosts := E7Txt.NouTabel(); vazute := E7Txt.NouTabel(); pool := E7Txt.NouTabel();
  TAB[0] := 9X; TAB[1] := 0X; wikiBaza := "https://ro.wikipedia.org"; nr := 0; nrp := 0; ni := 0; aleator := 0; nl := 0
END E7Web.


MODULE Eula7; (* Eula 7 scrisa in Oberon: gramatica pe reguli + sorobanul in a 7-a dimensiune + Opal ca supra-filtru.
  Aplicatie de vorbit (Conversatie): Ask / Feed / Importă, cele patru butoane ale geometriei, A− A+ le face pielea.
  Se face cu:  apk Eula7.Mod "Eula 7"  (dosarul Eula7/ de langa: unicode.bin, lexicon-ro.tsv, text.txt).
  Pion & Claude, 20.10.2026, din Eula 7 v8 (Java). *)

  IMPORT Conversatie, E7Txt, E7Disc, E7Gram, E7Mem, E7Sor, E7Roler, E7Motor, E7Fire, E7Web;

  CONST N = 65536;

  VAR
    BG, GOLD, VIOLET, DIM, TEXT, PANEL: INTEGER;
    dosar, memF, snapF, fireF, cale, nume: ARRAY 1100 OF CHAR;
    intrare, r: ARRAY N OF CHAR;
    n: ARRAY 4096 OF CHAR;
    loaded, dirty: BOOLEAN;
    pasc, pascut, greseli: INTEGER;         (* pasunea pe Wikipedia: cate mai sunt, cate am pascut *)
    oct: ARRAY 262144 OF BYTE; noct: INTEGER;
    buf: ARRAY 65536 OF BYTE;

  PROCEDURE Rgb(r, g, b: INTEGER): INTEGER;
  BEGIN RETURN -16777216 + r * 65536 + g * 256 + b
  END Rgb;

  PROCEDURE Cale(nm: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  BEGIN E7Txt.Copy(dosar, d); E7Txt.Add(d, "/"); E7Txt.Add(d, nm)
  END Cale;

  PROCEDURE Stat;
    VAR s: ARRAY 128 OF CHAR;
  BEGIN s := "știe "; E7Txt.AddNr(s, E7Mem.T); E7Txt.Add(s, " de semne · "); E7Txt.AddInt(s, E7Mem.ns); E7Txt.Add(s, " de fraze");
    Conversatie.Stare(s)
  END Stat;

  PROCEDURE StatIn(VAR s: ARRAY OF CHAR);
  BEGIN E7Txt.Add(s, "știe "); E7Txt.AddNr(s, E7Mem.T); E7Txt.Add(s, " de semne · "); E7Txt.AddInt(s, E7Mem.ns); E7Txt.Add(s, " de fraze")
  END StatIn;

  PROCEDURE Procent(p: INTEGER);
    VAR s: ARRAY 64 OF CHAR;
  BEGIN s := "citește… "; E7Txt.AddInt(s, p); E7Txt.Add(s, "%"); Conversatie.Stare(s)
  END Procent;

  (* ---------- UTF-8 spre fisierul memoriei ---------- *)

  PROCEDURE Oct(x: INTEGER);
  BEGIN
    IF noct = LEN(oct) THEN IF Conversatie.Adauga(memF, oct, noct) THEN END ; noct := 0 END ;
    oct[noct] := x MOD 256; INC(noct)
  END Oct;

  PROCEDURE Utf8(s: ARRAY OF CHAR);
    VAR i, c, d: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO
      c := ORD(s[i]); INC(i);
      IF c < 80H THEN Oct(c)
      ELSIF c < 800H THEN Oct(0C0H + c DIV 64); Oct(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0DC00H) & (i < LEN(s)) & (ORD(s[i]) >= 0DC00H) & (ORD(s[i]) < 0E000H) THEN
        d := ORD(s[i]); INC(i); c := 10000H + (c - 0D800H) * 400H + (d - 0DC00H);
        Oct(0F0H + c DIV 40000H); Oct(80H + c DIV 1000H MOD 64); Oct(80H + c DIV 64 MOD 64); Oct(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0E000H) THEN Oct(ORD("?"))
      ELSE Oct(0E0H + c DIV 1000H); Oct(80H + c DIV 64 MOD 64); Oct(80H + c MOD 64)
      END
    END
  END Utf8;

  PROCEDURE Scrie;
  BEGIN IF noct > 0 THEN IF Conversatie.Adauga(memF, oct, noct) THEN END ; noct := 0 END
  END Scrie;

  (* „\n␞timp<TAB>sursa\n” *)
  PROCEDURE Antet(src: ARRAY OF CHAR);
    VAR t: ARRAY 32 OF CHAR; s: ARRAY 4096 OF CHAR; i: INTEGER;
  BEGIN Conversatie.Acum(t); E7Txt.Copy(src, s); i := 0;
    WHILE s[i] # 0X DO IF (s[i] = 0AX) OR (s[i] = 9X) THEN s[i] := " " END ; INC(i) END ;
    Oct(0AH); Oct(1EH); Utf8(t); Oct(9); Utf8(s); Oct(0AH)
  END Antet;

  (* ce scrii devine memorie: in fisier si in cub, deodata *)
  PROCEDURE Mananca(text, src: ARRAY OF CHAR): INTEGER;
    VAR k: INTEGER;
  BEGIN Antet(src); Utf8(text); Scrie;
    E7Mem.CorpGol; E7Mem.CorpS(text); k := E7Mem.Adauga(0, src);
    dirty := TRUE;
    RETURN k
  END Mananca;

  PROCEDURE SalveazaFoto;
  BEGIN IF E7Mem.Salveaza(snapF, E7Disc.MarimeF(memF)) THEN dirty := FALSE END
  END SalveazaFoto;

  (* ---------- geometria ---------- *)

  PROCEDURE Stil(nr: INTEGER; t: ARRAY OF CHAR; nou: BOOLEAN);
  BEGIN
    IF nou THEN Conversatie.Buton(nr, t, GOLD, PANEL) ELSE Conversatie.Buton(nr, t, Rgb(2AH, 21H, 40H), TEXT) END
  END Stil;

  PROCEDURE Etichete;
  BEGIN
    IF E7Sor.spirala THEN Stil(1, "Spirală", TRUE) ELSE Stil(1, "Tor", FALSE) END ;
    IF E7Sor.fete THEN Stil(2, "Fețe: da", TRUE) ELSE Stil(2, "Fețe: nu", FALSE) END ;
    IF E7Sor.n7 = "Z" THEN Stil(3, "N7: ca Z7", FALSE) ELSIF E7Sor.n7 = "A" THEN Stil(3, "N7: scade", TRUE) ELSE Stil(3, "N7: oglindă", TRUE) END ;
    IF E7Sor.litere49 THEN Stil(4, "49 lit.", TRUE) ELSE Stil(4, "7 lit.", FALSE) END
  END Etichete;

  PROCEDURE Da(b: BOOLEAN; VAR s: ARRAY OF CHAR);
  BEGIN IF b THEN s := "1" ELSE s := "0" END
  END Da;

  PROCEDURE SalveazaGeo;
    VAR s: ARRAY 256 OF CHAR;
  BEGIN
    Da(E7Sor.spirala, s); Conversatie.Tine("spirala", s);
    Da(E7Sor.fete, s); Conversatie.Tine("fete", s);
    s[0] := E7Sor.n7; s[1] := 0X; Conversatie.Tine("n7", s);
    Da(E7Sor.litere49, s); Conversatie.Tine("litere49", s);
    Etichete;
    s := "cub: "; E7Sor.Descriere(n); E7Txt.Add(s, n); Conversatie.Stare(s)
  END SalveazaGeo;

  PROCEDURE CitesteGeo;
    VAR a, b, c, d: ARRAY 8 OF CHAR;
  BEGIN Conversatie.Setare("spirala", a); Conversatie.Setare("fete", b); Conversatie.Setare("n7", c); Conversatie.Setare("litere49", d);
    IF c[0] = 0X THEN c := "Z" END ;
    E7Sor.Seteaza(a = "1", b = "1", d = "1", c[0])
  END CitesteGeo;

  (* „geometrie” arata setarea; „geometrie spirală|tor”, „… fețe da|nu”, „… n7 z|a|c”, „… 49 da|nu”, „… veche” *)
  PROCEDURE Geometrie(q: ARRAY OF CHAR): BOOLEAN;
    VAR t, g: ARRAY 4096 OF CHAR; da: BOOLEAN; sp, fe, l49: BOOLEAN; n7: CHAR;
  BEGIN E7Txt.Copy(q, t); E7Txt.MicS(t); E7Txt.FoldS(t); E7Txt.Trim(t);
    da := E7Txt.Incepe(t, "geometrie");
    IF da THEN
      E7Txt.Sub(t, 9, E7Txt.Len(t), g); E7Txt.Trim(g);
      sp := E7Sor.spirala; fe := E7Sor.fete; l49 := E7Sor.litere49; n7 := E7Sor.n7;
      IF E7Txt.Incepe(g, "spiral") THEN sp := TRUE
      ELSIF E7Txt.Incepe(g, "tor") THEN sp := FALSE
      ELSIF E7Txt.Incepe(g, "fete da") THEN fe := TRUE
      ELSIF E7Txt.Incepe(g, "fete nu") THEN fe := FALSE
      ELSIF E7Txt.Incepe(g, "n7 ") THEN n7 := E7Txt.Mare(g[3])
      ELSIF E7Txt.Incepe(g, "49 da") OR E7Txt.Eq(g, "49") THEN l49 := TRUE
      ELSIF E7Txt.Incepe(g, "49 nu") OR E7Txt.Incepe(g, "7 litere") THEN l49 := FALSE
      ELSIF E7Txt.Eq(g, "veche") THEN sp := FALSE; fe := FALSE; n7 := "Z"; l49 := FALSE
      END ;
      E7Sor.Seteaza(sp, fe, l49, n7);
      SalveazaGeo;
      E7Sor.Descriere(r);
      E7Txt.AddCh(r, 0AX);
      E7Txt.Add(r, "(„geometrie spirală/tor”, „geometrie fețe da/nu”, „geometrie n7 z/a/c”, „geometrie 49 da/nu”, „geometrie veche”)");
      Conversatie.Spune(VIOLET, "Eula 7: ", r)
    END ;
    RETURN da
  END Geometrie;

  PROCEDURE Ajutor;
  BEGIN
    r := "Întreabă-mă orice: „care e cel mai important oraș din Moldova?”, „cine a inventat pianul?”."; E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "Definiții: „ce este cubul?”, „definește munca”."); E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "Feed: ce scrii în căsuță devine memorie."); E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "Importă: aleg un fișier (memoria Eulei vechi, eula-memorie.txt, dex-database.sql.gz de la dexonline, sau orice text)."); E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "Sub răspuns: ce verificări Opal au trecut (1 cuvintele, 3 sorobanul, 5 rolul, 7 fraza e curată, 11 contextul) și sursa."); E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "Geometria cubului: cele patru butoane de deasupra lui Ask (Tor/Spirală, Fețe, N7, 7/49 litere); aurii = altfel decât înainte. Sau scrii „geometrie veche”."); E7Txt.AddCh(r, 0AX);
    E7Txt.Add(r, "49 lit.: cuvântul intră în cub fără diacritice și întreg (până la 49 de litere), nu doar primele 7 — testat: de 3 ori mai puține confuzii între cuvinte, iartă diacriticele lipsă.");
    Conversatie.Spune(VIOLET, "Eula 7: ", r)
  END Ajutor;

  (* ---------- intrebari si mancare ---------- *)

  (* ---------- Faza 2: macină, wiki, pasunea ---------- *)

  (* 1 pagină, 7 pagini, 20 de pagini (in romana, de la 20 incolo „de”) *)
  PROCEDURE Cate(VAR d: ARRAY OF CHAR; x: INTEGER; unu, multe: ARRAY OF CHAR);
  BEGIN
    IF x = 1 THEN E7Txt.Add(d, "1 "); E7Txt.Add(d, unu)
    ELSE E7Txt.AddNr(d, x); IF (x MOD 100 = 0) & (x > 0) OR (x MOD 100 >= 20) THEN E7Txt.Add(d, " de") END ; E7Txt.Add(d, " "); E7Txt.Add(d, multe)
    END
  END Cate;

  (* milisecundele de la 1970 (ca text) -> „20.10.2026, 05:15 UTC” *)
  PROCEDURE Data(ms: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
    VAR s, i, z, era, doe, yoe, y, doy, mp, zi, luna, h, m: INTEGER;
  BEGIN s := 0; i := 0;
    WHILE (i < 10) & (ms[i] >= "0") & (ms[i] <= "9") DO s := s * 10 + ORD(ms[i]) - ORD("0"); INC(i) END ;
    z := s DIV 86400; h := s MOD 86400 DIV 3600; m := s MOD 3600 DIV 60;
    z := z + 719468; era := z DIV 146097; doe := z - era * 146097;          (* zilele -> data civila (H. Hinnant) *)
    yoe := (doe - doe DIV 1460 + doe DIV 36524 - doe DIV 146096) DIV 365;
    y := yoe + era * 400; doy := doe - (365 * yoe + yoe DIV 4 - yoe DIV 100);
    mp := (5 * doy + 2) DIV 153; zi := doy - (153 * mp + 2) DIV 5 + 1;
    IF mp < 10 THEN luna := mp + 3 ELSE luna := mp - 9 END ;
    IF luna <= 2 THEN INC(y) END ;
    d := ""; IF zi < 10 THEN E7Txt.AddCh(d, "0") END ; E7Txt.AddInt(d, zi); E7Txt.AddCh(d, ".");
    IF luna < 10 THEN E7Txt.AddCh(d, "0") END ; E7Txt.AddInt(d, luna); E7Txt.AddCh(d, "."); E7Txt.AddInt(d, y); E7Txt.Add(d, ", ");
    IF h < 10 THEN E7Txt.AddCh(d, "0") END ; E7Txt.AddInt(d, h); E7Txt.AddCh(d, ":");
    IF m < 10 THEN E7Txt.AddCh(d, "0") END ; E7Txt.AddInt(d, m); E7Txt.Add(d, " UTC")
  END Data;

  (* textul din E7Mem.corp (pagina macinata) intra in fisierul memoriei si in cub *)
  PROCEDURE MancaPagina(src: ARRAY OF CHAR): INTEGER;
    VAR i, c, d, k: INTEGER;
  BEGIN Antet(src); i := 0;
    WHILE i < E7Mem.corpN DO
      c := ORD(E7Txt.C(E7Mem.corp, i)); INC(i);
      IF c < 80H THEN Oct(c)
      ELSIF c < 800H THEN Oct(0C0H + c DIV 64); Oct(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0DC00H) & (i < E7Mem.corpN) THEN
        d := ORD(E7Txt.C(E7Mem.corp, i)); INC(i); c := 10000H + (c - 0D800H) * 400H + (d - 0DC00H);
        Oct(0F0H + c DIV 40000H); Oct(80H + c DIV 1000H MOD 64); Oct(80H + c DIV 64 MOD 64); Oct(80H + c MOD 64)
      ELSIF (c >= 0D800H) & (c < 0E000H) THEN Oct(ORD("?"))
      ELSE Oct(0E0H + c DIV 1000H); Oct(80H + c DIV 64 MOD 64); Oct(80H + c MOD 64)
      END
    END ;
    Scrie;
    k := E7Mem.Adauga(0, src); dirty := TRUE;
    RETURN k
  END MancaPagina;

  (* macina adresa a; intoarce codul din E7Web.Macina; scurt = raportul pentru pasune *)
  PROCEDURE Macina(a: ARRAY OF CHAR; scurt: BOOLEAN): INTEGER;
    VAR rez, k: INTEGER; m, src: ARRAY 4096 OF CHAR; t: ARRAY 32 OF CHAR; dt: ARRAY 64 OF CHAR;
  BEGIN Conversatie.Acum(t); Data(t, dt);
    rez := E7Web.Macina(a, dt, m);
    IF rez = 0 THEN
      IF E7Web.EWiki(E7Web.adresa) THEN src := "wikipedia: " ELSE
        src := "web: "; k := E7Txt.Pos("://", E7Web.gazda, 0) + 3; E7Txt.Sub(E7Web.gazda, k, E7Txt.Len(E7Web.gazda), m);
        E7Txt.Add(src, m); E7Txt.Add(src, " ")
      END ;
      E7Txt.Add(src, E7Web.titlu);
      k := MancaPagina(src); E7Web.Pasune;
      IF ~scurt THEN
        r := "Am măcinat „"; E7Txt.Add(r, E7Web.titlu); E7Txt.Add(r, "”: "); Cate(r, E7Web.semne, "semn", "semne"); E7Txt.Add(r, ", ");
        Cate(r, E7Web.nl, "legătură", "legături"); E7Txt.Add(r, ", "); Cate(r, k, "frază nouă", "fraze noi"); E7Txt.Add(r, " în memorie. Fișierul: ");
        E7Web.Scurt(E7Web.cale, r);
        IF ~E7Web.inDescarcari THEN E7Txt.Add(r, " (în aplicație: n-am încă voie la Download; am cerut-o, data viitoare îl pun acolo)") END ;
        Conversatie.Spune(VIOLET, "Eula 7: ", r)
      END ;
      rez := 0
    ELSIF ~scurt THEN
      IF rez = 1 THEN r := "robots.txt de pe "; E7Txt.Add(r, E7Web.adresa); E7Txt.Add(r, " nu mă lasă să macin pagina asta, așa că n-o macin.")
      ELSIF rez = 2 THEN r := "N-am putut citi robots.txt pentru "; E7Txt.Add(r, E7Web.adresa); E7Txt.Add(r, " (fără internet sau serverul nu răspunde). Fără el nu macin.")
      ELSIF rez = 3 THEN r := "Pagina n-a venit ("; E7Txt.Add(r, m); E7Txt.Add(r, "): "); E7Txt.Add(r, E7Web.adresa)
      ELSIF rez = 4 THEN r := "Nu e o pagină de text ("; E7Txt.Add(r, m); E7Txt.Add(r, "), n-o macin.")
      ELSE r := "N-am putut scrie fișierul "; E7Txt.Add(r, E7Web.cale)
      END ;
      Conversatie.Spune(VIOLET, "Eula 7: ", r)
    END ;
    RETURN rez
  END Macina;

  (* un pas de pasune: o pagina noua de pe Wikipedia, din legaturile celor pascute *)
  PROCEDURE Pasc;
    VAR a, m: ARRAY 2048 OF CHAR; r, incercari: INTEGER; gata: BOOLEAN;
  BEGIN gata := FALSE; incercari := 0;
    WHILE ~gata & (incercari < 3) DO
      IF ~E7Web.Urmatoarea(a) THEN
        pasc := 0; gata := TRUE;
        Conversatie.Spune(VIOLET, "Eula 7: ", "N-am mai găsit unde să pasc (toate legăturile știute sunt păscute).")
      ELSE
        Conversatie.Stare("pasc…");
        r := Macina(a, TRUE);
        IF r = 0 THEN
          E7Web.Pasune; INC(pascut); DEC(pasc); gata := TRUE; greseli := 0;
          m := "["; E7Txt.AddInt(m, pascut); E7Txt.Add(m, "/"); E7Txt.AddInt(m, pascut + pasc); E7Txt.Add(m, "] Wikipedia: ");
          E7Txt.Add(m, E7Web.titlu); E7Txt.Add(m, " — "); Cate(m, E7Web.semne, "semn", "semne");
          Conversatie.Spune(DIM, "", m)
        ELSE
          IF (r = 1) OR (r = 3) OR (r = 4) THEN E7Web.Sari(a) END ; INC(greseli);
          m := "[sar peste] "; E7Txt.Add(m, a); E7Txt.Add(m, ": ");
          IF r = 1 THEN E7Txt.Add(m, "robots.txt nu mă lasă")
          ELSIF r = 2 THEN E7Txt.Add(m, "robots.txt n-a răspuns (fără internet?)")
          ELSIF r = 3 THEN E7Txt.Add(m, "pagina n-a venit")
          ELSIF r = 4 THEN E7Txt.Add(m, "nu e text")
          ELSE E7Txt.Add(m, "n-am putut scrie fișierul "); E7Txt.Add(m, E7Web.cale)
          END ;
          Conversatie.Spune(DIM, "", m);
          IF (r = 2) OR (r = 5) OR (greseli >= 5) THEN
            pasc := 0; gata := TRUE;
            Conversatie.Spune(VIOLET, "Eula 7: ", "M-am oprit din păscut: nu merge (vezi rândul de mai sus).")
          END
        END ;
        INC(incercari)
      END
    END ;
    IF pasc <= 0 THEN
      Conversatie.Ceas(0);
      m := "Am păscut "; Cate(m, pascut, "pagină", "pagini"); E7Txt.Add(m, ". "); StatIn(m); E7Txt.Add(m, ".");
      Conversatie.Spune(VIOLET, "Eula 7: ", m); pasc := 0
    END ;
    Stat
  END Pasc;

  PROCEDURE Tic*;
  BEGIN IF loaded & (pasc > 0) THEN Pasc ELSE Conversatie.Ceas(0) END
  END Tic;

  PROCEDURE Numar(s: ARRAY OF CHAR; i: INTEGER): INTEGER;
    VAR r: INTEGER;
  BEGIN r := 0;
    WHILE s[i] = " " DO INC(i) END ;
    WHILE (s[i] >= "0") & (s[i] <= "9") & (r < 100000) DO r := r * 10 + ORD(s[i]) - ORD("0"); INC(i) END ;
    RETURN r
  END Numar;

  (* comenzile Fazei 2; TRUE daca a fost una *)
  PROCEDURE Comanda(q: ARRAY OF CHAR): BOOLEAN;
    VAR t, a: ARRAY 4096 OF CHAR; da: BOOLEAN; k, i: INTEGER;
  BEGIN E7Txt.Copy(q, t); E7Txt.MicS(t); E7Txt.FoldS(t); E7Txt.Trim(t); da := TRUE;
    IF E7Txt.Incepe(t, "macina ") OR E7Txt.Incepe(t, "macina:") THEN
      i := 7; E7Txt.Sub(q, i, E7Txt.Len(q), a); E7Txt.Trim(a);
      Conversatie.Stare("macin…"); k := Macina(a, FALSE); Stat
    ELSIF (t = "macinate") OR (t = "ce ai macinat") OR (t = "ce ai macinat?") THEN
      E7Web.Lista(r); Conversatie.Spune(VIOLET, "Eula 7: ", r)
    ELSIF E7Txt.Incepe(t, "citeste ") & (Numar(t, 8) > 0) THEN
      E7Web.Citeste(Numar(t, 8), r); Conversatie.Spune(VIOLET, "Eula 7: ", r)
    ELSIF (t = "wiki stop") OR (t = "wiki opreste") THEN
      pasc := 0; Conversatie.Ceas(0); Conversatie.Spune(VIOLET, "Eula 7: ", "Gata, nu mai pasc.")
    ELSIF E7Txt.Incepe(t, "wiki pasune") OR E7Txt.Incepe(t, "wiki pasc") THEN
      k := Numar(t, 11); IF k <= 0 THEN k := 10 END ; IF k > 1000 THEN k := 1000 END ;
      pasc := k; pascut := 0; greseli := 0;
      Conversatie.Spune(VIOLET, "Eula 7: ", "Mă duc să pasc pe Wikipedia, din legătură în legătură (doar pe unde mă lasă robots.txt). Poți vorbi cu mine între timp; „wiki stop” mă oprește.");
      Conversatie.Ceas(1000)
    ELSIF E7Txt.Incepe(t, "wiki ") THEN
      E7Txt.Sub(q, 5, E7Txt.Len(q), a); E7Txt.Trim(a); E7Web.WikiAdresa(a, t);
      Conversatie.Stare("macin…"); k := Macina(t, FALSE);
      IF k = 0 THEN E7Web.Pasune END ;
      Stat
    ELSE da := FALSE
    END ;
    RETURN da
  END Comanda;

  PROCEDURE Intreaba;
    VAR k: INTEGER; src: ARRAY 128 OF CHAR;
  BEGIN
    Conversatie.Intrare(intrare); E7Txt.Trim(intrare);
    IF intrare # "" THEN
      Conversatie.Spune(GOLD, "Tu: ", intrare);
      IF E7Txt.Eq(intrare, "?") THEN Ajutor
      ELSIF ~Geometrie(intrare) & ~Comanda(intrare) THEN
        Conversatie.Stare("se gândește…");
        n := "";
        E7Fire.Raspunde(intrare);
        IF E7Fire.fel = E7Fire.INVATA THEN
          src := "învățat de la "; IF E7Fire.nume # "" THEN E7Txt.Add(src, E7Fire.nume) ELSE E7Txt.Add(src, "Pion") END ;
          k := Mananca(intrare, src);
          E7Fire.AInvatat(intrare, r)
        ELSIF (E7Fire.fel = E7Fire.GATA) & (E7Fire.r1 = "") THEN
          E7Txt.Copy(E7Fire.r0, r)
        ELSE
          IF E7Fire.fel = E7Fire.NIMIC THEN E7Motor.Raspunde(intrare); r := ""
          ELSE E7Motor.Raspunde(E7Fire.r1); E7Txt.Copy(E7Fire.r0, r); E7Txt.Add(r, " ")
          END ;
          E7Txt.Add(r, E7Motor.raspuns); E7Txt.Copy(E7Motor.nota, n);
          E7Fire.Socoteste(E7Motor.sigur);
          FOR k := 0 TO E7Motor.nnec - 1 DO E7Fire.Cere(E7Motor.nec[k]) END ;
          E7Fire.Salveaza
        END ;
        Conversatie.Spune(VIOLET, "Eula 7: ", r);
        IF n # "" THEN r := "("; E7Txt.Add(r, n); E7Txt.Add(r, ")"); Conversatie.Spune(DIM, "", r) END ;
        Stat
      END
    END
  END Intreaba;

  PROCEDURE Hraneste;
    VAR k: INTEGER;
  BEGIN
    Conversatie.Intrare(intrare); E7Txt.Trim(intrare);
    IF intrare # "" THEN
      Conversatie.Spune(GOLD, "Tu: ", intrare);
      k := Mananca(intrare, "conversație");
      r := "Am ținut minte ("; E7Txt.AddInt(r, k); IF k = 1 THEN E7Txt.Add(r, " frază).") ELSE E7Txt.Add(r, " fraze).") END ;
      Conversatie.Spune(VIOLET, "Eula 7: ", r);
      Stat
    END
  END Hraneste;

  PROCEDURE Apasa*;
    VAR b: INTEGER; sp, fe, l49: BOOLEAN; n7: CHAR;
  BEGIN b := Conversatie.Apasat();
    IF ~loaded THEN (* inca porneste *)
    ELSIF (b = 0) OR (b = 11) THEN Intreaba
    ELSIF b = 12 THEN Hraneste
    ELSIF b = 13 THEN Conversatie.AlegeFisier
    ELSIF (b >= 1) & (b <= 4) THEN
      sp := E7Sor.spirala; fe := E7Sor.fete; l49 := E7Sor.litere49; n7 := E7Sor.n7;
      IF b = 1 THEN sp := ~sp
      ELSIF b = 2 THEN fe := ~fe
      ELSIF b = 3 THEN IF n7 = "Z" THEN n7 := "A" ELSIF n7 = "A" THEN n7 := "C" ELSE n7 := "Z" END
      ELSE l49 := ~l49
      END ;
      E7Sor.Seteaza(sp, fe, l49, n7); SalveazaGeo
    END
  END Apasa;

  (* Importă: memoria Eulei vechi (bucati cu „\n␞”), sau orice text; dexonline (.gz) inca nu *)
  PROCEDURE Primeste*;
    VAR k, b0, b1, inainte, poz, x: INTEGER; memorie, prev: BOOLEAN; src: ARRAY 1200 OF CHAR;
  BEGIN
    Conversatie.Ales(cale, nume);
    IF cale = "" THEN Conversatie.Spune(DIM, "", "N-ai ales niciun fișier.")
    ELSIF E7Disc.Citeste(cale) THEN
      b0 := E7Disc.Octet(); b1 := E7Disc.Octet();
      IF (b0 = 1FH) & (b1 = 8BH) THEN
        E7Disc.InchideC;
        Conversatie.Spune(VIOLET, "Eula 7: ", "E un fișier .gz (dexonline?). Pe acela încă nu l-am mutat în Oberon: îl mănânc doar Eula 7 cea veche, în Java.")
      ELSE
        Conversatie.Spune(DIM, "", "Import… (memoria mare durează câteva minute)");
        memorie := FALSE; prev := b0 = 0AH; x := b1;
        IF prev & (b1 = 1EH) THEN memorie := TRUE END ;
        WHILE ~memorie & (x >= 0) DO prev := x = 0AH; x := E7Disc.Octet(); IF prev & (x = 1EH) THEN memorie := TRUE END END ;
        inainte := E7Mem.ns; poz := E7Disc.MarimeF(memF);
        IF memorie THEN Antet("memoria Eulei vechi") ELSE Antet(nume) END ;
        Scrie;
        IF E7Disc.Citeste(cale) THEN
          k := E7Disc.Octeti(buf, LEN(buf));
          WHILE k > 0 DO IF Conversatie.Adauga(memF, buf, k) THEN END ; k := E7Disc.Octeti(buf, LEN(buf)) END ;
          E7Disc.InchideC
        END ;
        E7Disc.Sterge(cale);
        E7Mem.ArataCu(Procent); k := E7Mem.Citeste(memF, poz); E7Mem.ArataCu(NIL);
        dirty := TRUE; SalveazaFoto;
        src := "Am mâncat "; E7Txt.AddInt(src, E7Mem.ns - inainte); E7Txt.Add(src, " de fraze din „"); E7Txt.Add(src, nume);
        E7Txt.Add(src, "”. "); StatIn(src); E7Txt.Add(src, ".");
        Conversatie.Spune(VIOLET, "Eula 7: ", src)
      END
    END ;
    Stat
  END Primeste;

  PROCEDURE Pauza*;
  BEGIN IF loaded & dirty THEN SalveazaFoto END
  END Pauza;

  (* ---------- pornirea ---------- *)

  PROCEDURE Porneste*;
    VAR cov, noi, k: INTEGER; t: ARRAY 32 OF CHAR;
  BEGIN
    Conversatie.Titlu("EULA 7"); Conversatie.Stare("pornesc…");
    Conversatie.Buton(11, "Ask", GOLD, PANEL); Conversatie.Buton(12, "Feed", Rgb(9BH, 5CH, 0F6H), Rgb(255, 255, 255));
    Conversatie.Buton(13, "Importă", Rgb(3AH, 2EH, 52H), TEXT);
    CitesteGeo; Etichete;
    Conversatie.Spune(VIOLET, "Eula 7: ", "Salut! Sunt Eula 7. Țin minte fraze și le caut printr-un cub în a 7-a dimensiune; Opal mă oprește când nu știu sigur. Întreabă-mă orice, sau „cine ești?”, „ce știi să faci?”.");
    Conversatie.Dosar(dosar); Cale("memorie7.txt", memF); Cale("index7.bin", snapF); Cale("fire.txt", fireF);
    IF ~Conversatie.Resursa("unicode.bin", cale) OR ~E7Txt.Incarca(cale) THEN
      Conversatie.Spune(VIOLET, "Eula 7: ", "Am pățit ceva la pornire: lipsește unicode.bin (din dosarul Eula7/ de lângă Eula7.Mod).")
    ELSE
      E7Motor.Pregateste;
      E7Fire.Incarca(fireF); E7Web.Porneste(dosar);
      Conversatie.Stare("citesc gramatica…");
      IF Conversatie.Resursa("lexicon-ro.tsv", cale) & E7Gram.Incarca(cale) THEN END ;
      IF ~E7Disc.Exista(memF) & Conversatie.Resursa("text.txt", cale) THEN
        Conversatie.Acum(t); Oct(0AH); Oct(1EH); Utf8(t); Oct(9); Utf8("nota Eula 0.1"); Oct(0AH); Scrie;
        IF E7Disc.Citeste(cale) THEN
          k := E7Disc.Octeti(buf, LEN(buf));
          WHILE k > 0 DO IF Conversatie.Adauga(memF, buf, k) THEN END ; k := E7Disc.Octeti(buf, LEN(buf)) END ;
          E7Disc.InchideC
        END
      END ;
      Conversatie.Stare("pornire rapidă…");
      cov := E7Mem.Incarca(snapF);
      IF (cov < 0) OR (cov > E7Disc.MarimeF(memF)) THEN cov := 0; E7Mem.Goleste END ;
      E7Roler.Uita;
      E7Mem.ArataCu(Procent);
      noi := E7Mem.Citeste(memF, cov);
      E7Mem.ArataCu(NIL);
      loaded := TRUE;
      IF (cov = 0) OR (noi > 0) THEN SalveazaFoto END ;
      IF cov > 0 THEN Conversatie.Spune(DIM, "", "(pornire rapidă)")
      ELSE Conversatie.Spune(DIM, "", "(am citit memoria și am făcut-o gata indexată; data viitoare pornesc repede)")
      END
    END ;
    Stat
  END Porneste;

BEGIN
  BG := Rgb(0EH, 0AH, 16H); PANEL := Rgb(1AH, 14H, 26H); GOLD := Rgb(255, 0C5H, 2EH); VIOLET := Rgb(0B1H, 8CH, 255);
  DIM := Rgb(9CH, 8FH, 0B8H); TEXT := Rgb(0F2H, 0EEH, 0F8H);
  loaded := FALSE; dirty := FALSE; noct := 0; pasc := 0; pascut := 0
END Eula7.
