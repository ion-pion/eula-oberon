MODULE Soroban7; (* Eula Oberon: sorobanul in a 7-a dimensiune (din Eula 7, ideea lui Pion).
  Torul Z7^7 (7^7 = 823.543 de cuburi), fiecare centru porneste de la 5 (piatra soarelui).
  Baza 7 fara zero: B7(n) = ((n-1) mod 7) + 1. Un colt e comun pentru 2^7 = 128 de cuburi, deci un impuls pleaca
  pe 128 de raze diagonale, o tura (7 cuburi) fiecare: centru = B7(centru + impuls + 2), iar valoarea noua merge mai departe.
  Un cuvant intra prin coltul dat de primele lui 7 litere, cate una pe fiecare axa (litera lipsa = 5); impulsurile sunt
  literele, pe rand. Valoarea unei litere = B7(locul ei in alfabetul romanesc de 31 de litere). *)

  CONST D = 7; N = 823543; MaxAt = 65536;

  TYPE Stare* = POINTER TO StareDesc;
    StareDesc* = RECORD
      v: ARRAY N OF BYTE;
      mark: ARRAY N OF BOOLEAN;
      at: ARRAY MaxAt OF INTEGER;
      n: INTEGER
    END ;

  VAR sq*, sf*: Stare;
    P7: ARRAY D OF INTEGER;
    alfabet: ARRAY 40 OF CHAR;

  PROCEDURE B7(n: INTEGER): INTEGER;
  BEGIN RETURN (n - 1) MOD 7 + 1
  END B7;

  PROCEDURE Val(c: CHAR): INTEGER;
    VAR p, r: INTEGER;
  BEGIN p := 0;
    WHILE (alfabet[p] # 0X) & (alfabet[p] # c) DO INC(p) END ;
    IF alfabet[p] # 0X THEN r := B7(p + 1)
    ELSIF (c >= "0") & (c <= "9") THEN r := B7(ORD(c) - ORD("0") + 1)
    ELSE r := -1
    END ;
    RETURN r
  END Val;

  PROCEDURE Nou(): Stare;
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

  PROCEDURE Impuls(s: Stare; VAR colt: ARRAY OF INTEGER; val: INTEGER);
    VAR c: ARRAY D OF INTEGER; dir, k, w, step, i, nv: INTEGER;
  BEGIN
    FOR dir := 0 TO 127 DO
      FOR k := 0 TO D - 1 DO IF ODD(ASR(dir, k)) THEN c[k] := colt[k] + 6 ELSE c[k] := colt[k] END END ;
      w := val;
      FOR step := 0 TO 6 DO
        i := 0;
        FOR k := 0 TO D - 1 DO i := i + (c[k] MOD 7) * P7[k] END ;
        IF ~s.mark[i] & (s.n < MaxAt) THEN s.mark[i] := TRUE; s.at[s.n] := i; INC(s.n) END ;
        IF s.mark[i] THEN
          nv := B7(s.v[i] + w + 2); s.v[i] := nv; w := nv
        END ;
        FOR k := 0 TO D - 1 DO IF ODD(ASR(dir, k)) THEN c[k] := c[k] + 6 ELSE c[k] := c[k] + 1 END END
      END
    END
  END Impuls;

  PROCEDURE Cuvant*(s: Stare; w: ARRAY OF CHAR);
    VAR v: ARRAY D OF INTEGER; colt: ARRAY D OF INTEGER; n, i, k: INTEGER;
  BEGIN n := 0; i := 0;
    WHILE (i < LEN(w)) & (w[i] # 0X) & (n < 7) DO
      k := Val(w[i]); IF k > 0 THEN v[n] := k; INC(n) END ;
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
  sq := Nou(); sf := Nou()
END Soroban7.
