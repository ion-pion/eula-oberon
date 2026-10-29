MODULE Litere; (* Eula Oberon: literele (romana + Oberon) si sirurile mici. Pion & Claude, 12.10.2026 *)

  CONST HS = 2048;   (* tabela cuvintelor de umplutura *)

  VAR stopA, stopN: ARRAY HS OF INTEGER;
    stopPool: ARRAY 4096 OF CHAR; nsp: INTEGER;

  (* ---------- felul literelor ---------- *)

  PROCEDURE Litera*(c: CHAR): BOOLEAN;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    RETURN (o >= 41H) & (o <= 5AH) OR (o >= 61H) & (o <= 7AH)
      OR (o = 0AAH) OR (o = 0B5H) OR (o = 0BAH)
      OR (o >= 0C0H) & (o <= 2AFH) & (o # 0D7H) & (o # 0F7H)
      OR (o >= 370H) & (o <= 3FFH) & (o # 37EH) & (o # 387H)
      OR (o >= 400H) & (o <= 52FH) & ((o < 482H) OR (o > 489H))
      OR (o >= 3040H) & (o <= 30FFH) OR (o >= 4E00H) & (o <= 9FFFH) OR (o >= 0AC00H) & (o <= 0D7A3H)
      OR (o >= 1E00H) & (o <= 1FFFH) OR (o >= 0FB00H) & (o <= 0FB06H) OR (o >= 0FF21H) & (o <= 0FF3AH) OR (o >= 0FF41H) & (o <= 0FF5AH)
  END Litera;

  PROCEDURE Cifra*(c: CHAR): BOOLEAN;
  BEGIN RETURN (c >= "0") & (c <= "9")
  END Cifra;

  PROCEDURE LiteraSauCifra*(c: CHAR): BOOLEAN;
  BEGIN RETURN Litera(c) OR Cifra(c)
  END LiteraSauCifra;

  (* \w din expresiile Java: doar ASCII *)
  PROCEDURE Cuvant*(c: CHAR): BOOLEAN;
  BEGIN RETURN (c >= "a") & (c <= "z") OR (c >= "A") & (c <= "Z") OR Cifra(c) OR (c = "_")
  END Cuvant;

  PROCEDURE Blanc*(c: CHAR): BOOLEAN;
  BEGIN RETURN (c <= " ") & (c # 0X)
  END Blanc;

  PROCEDURE Mare*(c: CHAR): BOOLEAN;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    RETURN (o >= 41H) & (o <= 5AH) OR (o >= 0C0H) & (o <= 0DEH) & (o # 0D7H)
      OR (o >= 100H) & (o <= 17FH) & ~ODD(o) OR (o = 218H) OR (o = 21AH)
      OR (o >= 391H) & (o <= 3A9H) OR (o >= 400H) & (o <= 42FH)
  END Mare;

  PROCEDURE Mica*(c: CHAR): BOOLEAN;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    RETURN (o >= 61H) & (o <= 7AH) OR (o >= 0DFH) & (o <= 0FFH) & (o # 0F7H)
      OR (o >= 100H) & (o <= 17FH) & ODD(o) OR (o = 219H) OR (o = 21BH)
      OR (o >= 3B1H) & (o <= 3C9H) OR (o >= 430H) & (o <= 45FH)
  END Mica;

  (* litera mica *)
  PROCEDURE Mic*(c: CHAR): CHAR;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    IF (o >= 41H) & (o <= 5AH) OR (o >= 0C0H) & (o <= 0DEH) & (o # 0D7H) THEN o := o + 20H
    ELSIF (o >= 100H) & (o <= 17FH) & ~ODD(o) OR (o = 218H) OR (o = 21AH) THEN o := o + 1
    ELSIF (o >= 391H) & (o <= 3A9H) OR (o >= 410H) & (o <= 42FH) THEN o := o + 20H
    ELSIF (o >= 400H) & (o <= 40FH) THEN o := o + 50H
    END ;
    RETURN CHR(o)
  END Mic;

  (* fara diacritice: ă â -> a, î -> i, ș ş -> s, ț ţ -> t *)
  PROCEDURE Fold*(c: CHAR): CHAR;
    VAR o: INTEGER;
  BEGIN o := ORD(c);
    IF (o = 103H) OR (o = 0E2H) THEN c := "a"
    ELSIF o = 0EEH THEN c := "i"
    ELSIF (o = 219H) OR (o = 15FH) THEN c := "s"
    ELSIF (o = 21BH) OR (o = 163H) THEN c := "t"
    ELSIF (o = 102H) OR (o = 0C2H) THEN c := "A"
    ELSIF o = 0CEH THEN c := "I"
    ELSIF (o = 218H) OR (o = 15EH) THEN c := "S"
    ELSIF (o = 21AH) OR (o = 162H) THEN c := "T"
    END ;
    RETURN c
  END Fold;

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
        IF (x < 0) & (q * 10 # x) THEN q := q + 1 END ;   (* impartire spre zero *)
        t[i] := CHR(ORD("0") + ABS(x - q * 10)); INC(i); x := q
      END ;
      WHILE i > 0 DO DEC(i); AddCh(d, t[i]) END
    END
  END AddInt;

  (* incepe s cu p? *)
  PROCEDURE Incepe*(s, p: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(p)) & (p[i] # 0X) & (i < LEN(s)) & (s[i] = p[i]) DO INC(i) END ;
    RETURN (i >= LEN(p)) OR (p[i] = 0X)
  END Incepe;

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

  (* minuscule, fara diacritice (pe loc) *)
  PROCEDURE MicFold*(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO s[i] := Fold(Mic(s[i])); INC(i) END
  END MicFold;

  PROCEDURE FoldS*(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO s[i] := Fold(s[i]); INC(i) END
  END FoldS;

  PROCEDURE MicS*(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO s[i] := Mic(s[i]); INC(i) END
  END MicS;

  (* scoate spatiile (<= " ") de la capete *)
  PROCEDURE Trim*(VAR s: ARRAY OF CHAR);
    VAR i, j, n: INTEGER;
  BEGIN n := Len(s); i := 0;
    WHILE (i < n) & (s[i] <= " ") DO INC(i) END ;
    WHILE (n > i) & (s[n-1] <= " ") DO DEC(n) END ;
    j := 0;
    WHILE i < n DO s[j] := s[i]; INC(i); INC(j) END ;
    s[j] := 0X
  END Trim;

  (* bucata [a, b) din s *)
  PROCEDURE Sub*(s: ARRAY OF CHAR; a, b: INTEGER; VAR d: ARRAY OF CHAR);
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (a < b) & (a < LEN(s)) & (j < LEN(d) - 1) DO d[j] := s[a]; INC(a); INC(j) END ;
    d[j] := 0X
  END Sub;

  (* String.hashCode() din Java, fara semn: aceeasi intrebare -> aceeasi formulare *)
  PROCEDURE Seed*(s: ARRAY OF CHAR): INTEGER;
    VAR h, i: INTEGER;
  BEGIN h := 0; i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO h := 31 * h + ORD(s[i]); INC(i) END ;
    IF h < 0 THEN h := h + 2147483647; h := h + 1 END ;
    RETURN h
  END Seed;

  PROCEDURE Hash*(s: ARRAY OF CHAR): INTEGER;
  BEGIN RETURN Seed(s)
  END Hash;

  (* ---------- cuvintele de umplutura (fara diacritice) ---------- *)

  PROCEDURE StopPus(w: ARRAY OF CHAR; a, n: INTEGER): BOOLEAN;
    VAR h, k, i: INTEGER; ok: BOOLEAN;
  BEGIN h := 0; i := 0;
    WHILE i < n DO h := 31 * h + ORD(w[a+i]); INC(i) END ;
    IF h < 0 THEN h := h + 2147483647; h := h + 1 END ;
    k := h MOD HS; ok := FALSE;
    WHILE ~ok & (stopN[k] # 0) DO
      IF stopN[k] = n THEN
        i := 0;
        WHILE (i < n) & (stopPool[stopA[k] + i] = w[a+i]) DO INC(i) END ;
        ok := i = n
      END ;
      IF ~ok THEN k := (k + 1) MOD HS END
    END ;
    RETURN ok
  END StopPus;

  PROCEDURE Stop*(w: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN StopPus(w, 0, Len(w))
  END Stop;

  PROCEDURE PuneStop(VAR w: ARRAY OF CHAR; a, n: INTEGER);
    VAR h, k, i: INTEGER;
  BEGIN
    IF ~StopPus(w, a, n) THEN
      h := 0; i := 0;
      WHILE i < n DO h := 31 * h + ORD(w[a+i]); INC(i) END ;
      IF h < 0 THEN h := h + 2147483647; h := h + 1 END ;
      k := h MOD HS;
      WHILE stopN[k] # 0 DO k := (k + 1) MOD HS END ;
      stopA[k] := nsp; stopN[k] := n;
      i := 0;
      WHILE i < n DO stopPool[nsp] := w[a+i]; INC(nsp); INC(i) END
    END
  END PuneStop;

  PROCEDURE Stopuri(s: ARRAY OF CHAR);
    VAR w: ARRAY 400 OF CHAR; i, a, n: INTEGER;
  BEGIN Copy(s, w); MicFold(w); n := Len(w); i := 0;
    WHILE i < n DO
      WHILE (i < n) & (w[i] = " ") DO INC(i) END ;
      a := i;
      WHILE (i < n) & (w[i] # " ") DO INC(i) END ;
      IF i > a THEN PuneStop(w, a, i - a) END
    END
  END Stopuri;

  (* cuvant cu sens: macar 3 litere si nu de umplutura (w e deja fara diacritice) *)
  PROCEDURE Continut*(w: ARRAY OF CHAR): BOOLEAN;
    VAR n: INTEGER;
  BEGIN n := Len(w);
    RETURN (n >= 3) & ~StopPus(w, 0, n)
  END Continut;

BEGIN nsp := 0;
  Stopuri("și si sau dar iar în in la pe cu de din pentru prin spre către catre despre după dupa până pana fără fara sub peste");
  Stopuri("între intre lângă langa un o unui unei niște niste cel cea cei cele al a ai ale lui ei lor el ea ele eu tu noi voi se să sa");
  Stopuri("ca că ce care cine cum când cand unde cât cat este e sunt era au am are fost fi nu mai foarte acest această aceasta acesta");
  Stopuri("aceste asta tot toate doar chiar încă inca deja deci dacă daca ori ne va le îl il îi ii mi ți ti nici decât decat etc ceva");
  Stopuri("fiecare orice alte alt alta altă poate pot trebuie vor vom ar aș as stii știi spune arata arată imi îmi");
  Stopuri("the and for with from this that are not was were has have had but can will its into then than also only may such");
  Stopuri("which when where what who how all any each one two");
  Stopuri("der die das und ist ein eine einen nicht mit von für fur auf den dem des wird sind oder bei als auch noch nur")
END Litere.
