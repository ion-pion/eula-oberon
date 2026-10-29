MODULE Memorie; (* Eula Oberon: memoria. Ce mananca ea sunt fisiere; fiecare fisier Oberon e taiat de gramatica
  in unitati (antetul modulului, un tip, un grup de constante sau variabile, o procedura, corpul modulului) — unitatea
  ia locul frazei din Eula 7. Pentru fiecare unitate tine minte cuvintele ei (numele din cod, despartite si pe bucati:
  WriteString -> writestring, write, string; plus cuvintele din comentarii si siruri).
  Textele stau in bucati de 64 K semne, ca paginile din Files al lui Wirth. *)

  IMPORT Litere, Gramatica, Disc;

  CONST
    CB = 65536; MaxCh = 1024; MaxNume = 256;
    MaxRec* = 16384; MaxU* = 150000; MaxD* = 300000; MaxL* = 300000; MaxP* = 2500000; MaxImp = 150000;
    HL = 1048576; HD = 1048576; HM = 65536; HW = 32768; MaxW* = 8000; MaxWB = 600000;
    KModul* = 0; KConst* = 1; KType* = 2; KVar* = 3; KProc* = 4; KCorp* = 5; KText* = 6;
    MAGIC = 45554F42H; VER = 3;

  TYPE Bucata = POINTER TO BucataDesc;
    BucataDesc = RECORD c: ARRAY CB OF CHAR END;

  VAR
    txt: ARRAY MaxCh OF Bucata; T*: INTEGER;              (* textele fisierelor *)
    pool: ARRAY MaxNume OF Bucata; NP: INTEGER;           (* numele: surse, module, unitati, leme, greseli *)

    nrec*: INTEGER;
    recA*, recN*, recSrcA*, recSrcN*, recModA*, recModN*, recDial*, recErrA*, recErrN*, recImpA*, recImpN*,
    recU0*, recU1*, recRang*, recNextMod: ARRAY MaxRec OF INTEGER;
    nimp: INTEGER; impA*, impN*: ARRAY MaxImp OF INTEGER;

    nu*: INTEGER;
    uRec*, uFrom*, uTo*, uHead*, uKind*, uNameA*, uNameN*, uLemA*, uLemN*: ARRAY MaxU OF INTEGER;
    uExp*, uCurat*: ARRAY MaxU OF BOOLEAN;

    nd*: INTEGER;
    dRec*, dFrom*, dTo*, dKind*, dLevel*, dNameA*, dNameN*, dNext: ARRAY MaxD OF INTEGER;
    dExp*: ARRAY MaxD OF BOOLEAN;

    nl*: INTEGER;
    lemA*, lemN*, lemCnt*, lemHead, lemTail: ARRAY MaxL OF INTEGER;
    np: INTEGER;
    ulem*, pUnit, pNext: ARRAY MaxP OF INTEGER;

    hashL: ARRAY HL OF INTEGER;                            (* id+1 *)
    hashD: ARRAY HD OF INTEGER;                            (* primul nume declarat+1, dupa numele cu litere mici *)
    hashM: ARRAY HM OF INTEGER;                            (* primul fisier+1 cu modulul, dupa nume mic *)

    nrMod, nrProc, nrLinii: INTEGER;

    (* cuvintele unui text, pe rand si fara dubluri *)
    ncw*: INTEGER; cwA*, cwN*: ARRAY MaxW OF INTEGER; cwb*: ARRAY MaxWB OF CHAR; ncwb: INTEGER;
    hw, hwN, hwStamp: ARRAY HW OF INTEGER; stamp: INTEGER;
    kw: ARRAY 34 OF ARRAY 12 OF CHAR;

  (* ---------- depozitele ---------- *)

  PROCEDURE PuneText(c: CHAR);
  BEGIN
    IF T DIV CB < MaxCh THEN
      IF txt[T DIV CB] = NIL THEN NEW(txt[T DIV CB]) END ;
      txt[T DIV CB].c[T MOD CB] := c; INC(T)
    END
  END PuneText;

  PROCEDURE Ch*(pos: INTEGER): CHAR;                       (* semnul de la pozitia pos din toate textele *)
  BEGIN RETURN txt[pos DIV CB].c[pos MOD CB]
  END Ch;

  PROCEDURE RCh*(r, off: INTEGER): CHAR;                  (* semnul off din fisierul r *)
    VAR pos: INTEGER;
  BEGIN pos := recA[r] + off;
    RETURN txt[pos DIV CB].c[pos MOD CB]
  END RCh;

  PROCEDURE PuneNume(c: CHAR);
  BEGIN
    IF NP DIV CB < MaxNume THEN
      IF pool[NP DIV CB] = NIL THEN NEW(pool[NP DIV CB]) END ;
      pool[NP DIV CB].c[NP MOD CB] := c; INC(NP)
    END
  END PuneNume;

  PROCEDURE PCh*(pos: INTEGER): CHAR;
  BEGIN RETURN pool[pos DIV CB].c[pos MOD CB]
  END PCh;

  (* pune un sir in depozitul de nume; a = inceputul, intoarce lungimea *)
  PROCEDURE NumeNou(s: ARRAY OF CHAR; VAR a, n: INTEGER);
    VAR i: INTEGER;
  BEGIN a := NP; i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO PuneNume(s[i]); INC(i) END ;
    n := i
  END NumeNou;

  PROCEDURE NumeIn*(a, n: INTEGER; VAR d: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < n) & (i < LEN(d) - 1) DO d[i] := PCh(a + i); INC(i) END ;
    d[i] := 0X
  END NumeIn;

  PROCEDURE NumeEq(a, n: INTEGER; s: ARRAY OF CHAR; mic: BOOLEAN): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN; c: CHAR;
  BEGIN r := TRUE; i := 0;
    WHILE r & (i < n) DO
      c := PCh(a + i); IF mic THEN c := Litere.Mic(c) END ;
      r := (i < LEN(s)) & (c = s[i]); INC(i)
    END ;
    RETURN r & ((n >= LEN(s)) OR (s[n] = 0X))
  END NumeEq;

  PROCEDURE HashNume(a, n: INTEGER; mic: BOOLEAN): INTEGER;
    VAR h, i: INTEGER; c: CHAR;
  BEGIN h := 0; i := 0;
    WHILE i < n DO c := PCh(a + i); IF mic THEN c := Litere.Mic(c) END ; h := 31 * h + ORD(c); INC(i) END ;
    IF h < 0 THEN h := h + 2147483647; h := h + 1 END ;
    RETURN h
  END HashNume;

  PROCEDURE SrcIn*(r: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(recSrcA[r], recSrcN[r], d)
  END SrcIn;

  PROCEDURE ModIn*(r: INTEGER; VAR d: ARRAY OF CHAR);     (* "" daca fisierul nu e un modul *)
  BEGIN
    IF recModN[r] > 0 THEN NumeIn(recModA[r], recModN[r], d) ELSE d[0] := 0X END
  END ModIn;

  PROCEDURE UNumeIn*(u: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(uNameA[u], uNameN[u], d)
  END UNumeIn;

  PROCEDURE DNumeIn*(x: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(dNameA[x], dNameN[x], d)
  END DNumeIn;

  PROCEDURE LemaIn*(id: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(lemA[id], lemN[id], d)
  END LemaIn;

  PROCEDURE ImpIn*(i: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(impA[i], impN[i], d)
  END ImpIn;

  PROCEDURE DialIn*(r: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN
    IF recDial[r] = 0 THEN d := "Oberon-07" ELSIF recDial[r] = 1 THEN d := "Oberon-2"
    ELSIF recDial[r] = 2 THEN d := "cu greșeli" ELSE d := "text"
    END
  END DialIn;

  PROCEDURE ErrIn*(r: INTEGER; VAR d: ARRAY OF CHAR);
  BEGIN NumeIn(recErrA[r], recErrN[r], d)
  END ErrIn;

  (* ---------- cuvintele ---------- *)

  PROCEDURE CuvantRezervat(VAR w: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; k := 0;
    IF (w[0] >= "A") & (w[0] <= "Z") THEN
      WHILE ~r & (k < 34) DO r := kw[k] = w; INC(k) END
    END ;
    RETURN r
  END CuvantRezervat;

  PROCEDURE CwGol*;
  BEGIN ncw := 0; ncwb := 0; INC(stamp)
  END CwGol;

  PROCEDURE CwAre(w: ARRAY OF CHAR; h: INTEGER; VAR k: INTEGER): BOOLEAN;
    VAR r, eq: BOOLEAN; i, n: INTEGER;
  BEGIN k := h MOD HW; r := FALSE;
    WHILE ~r & (hwStamp[k] = stamp) DO
      n := hwN[k]; eq := TRUE; i := 0;
      WHILE eq & (i < n) DO eq := cwb[hw[k] + i] = w[i]; INC(i) END ;
      IF eq & ((n >= LEN(w)) OR (w[n] = 0X)) THEN r := TRUE ELSE k := (k + 1) MOD HW END
    END ;
    RETURN r
  END CwAre;

  (* adauga w la lista (daca nu e deja); la pozitia poz, sau la sfarsit cand poz < 0 *)
  PROCEDURE CwPune*(w: ARRAY OF CHAR; poz: INTEGER);
    VAR h, k, i, n: INTEGER;
  BEGIN h := Litere.Hash(w);
    IF ~CwAre(w, h, k) & (ncw < MaxW) & (ncw < HW DIV 2) THEN
      n := Litere.Len(w);
      IF ncwb + n < MaxWB THEN
        IF (poz < 0) OR (poz > ncw) THEN poz := ncw END ;
        i := ncw;
        WHILE i > poz DO cwA[i] := cwA[i-1]; cwN[i] := cwN[i-1]; DEC(i) END ;
        cwA[poz] := ncwb; cwN[poz] := n;
        hw[k] := ncwb; hwN[k] := n; hwStamp[k] := stamp; INC(ncw);
        i := 0;
        WHILE i < n DO cwb[ncwb] := w[i]; INC(ncwb); INC(i) END
      END
    END
  END CwPune;

  PROCEDURE CwIn*(i: INTEGER; VAR d: ARRAY OF CHAR);
    VAR j: INTEGER;
  BEGIN j := 0;
    WHILE (j < cwN[i]) & (j < LEN(d) - 1) DO d[j] := cwb[cwA[i] + j]; INC(j) END ;
    d[j] := 0X
  END CwIn;

  PROCEDURE CwContine*(w: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER;
  BEGIN RETURN CwAre(w, Litere.Hash(w), k)
  END CwContine;

  (* cuvintele din t[from, to): litere mici, fara diacritice; numele din cod si pe bucati (WriteString -> write, string) *)
  PROCEDURE Cuvinte*(VAR t: ARRAY OF CHAR; from, to: INTEGER);
    VAR i, a, wl, k, st, np2, j, m: INTEGER; c, p, q: CHAR; taie: BOOLEAN;
      w, l, part: ARRAY 64 OF CHAR; pa, pb: ARRAY 64 OF INTEGER;
  BEGIN CwGol; i := from;
    WHILE i < to DO
      c := t[i];
      IF ~Litere.Litera(c) THEN INC(i)
      ELSE a := i;
        WHILE (i < to) & (Litere.LiteraSauCifra(t[i]) OR (t[i] = "_")) DO INC(i) END ;
        wl := i - a; IF wl > 63 THEN wl := 63 END ;
        FOR k := 0 TO wl - 1 DO w[k] := t[a+k] END ;
        w[wl] := 0X;
        IF ~CuvantRezervat(w) THEN
          FOR k := 0 TO wl - 1 DO l[k] := Litere.Fold(Litere.Mic(w[k])) END ;
          l[wl] := 0X;
          IF Litere.Continut(l) THEN CwPune(l, -1) END ;
          st := 0; np2 := 0;
          FOR k := 1 TO wl DO
            taie := k = wl;
            IF ~taie THEN
              p := w[k-1]; q := w[k];
              taie := Litere.Mica(p) & Litere.Mare(q) OR (q = "_") OR (p = "_") OR Litere.Litera(p) & Litere.Cifra(q)
                OR (k + 1 < wl) & Litere.Mare(p) & Litere.Mare(q) & Litere.Mica(w[k+1])
            END ;
            IF taie THEN
              m := 0; FOR j := st TO k - 1 DO IF w[j] # "_" THEN INC(m) END END ;
              IF (m > 0) & (np2 < 64) THEN pa[np2] := st; pb[np2] := k; INC(np2) END ;
              st := k
            END
          END ;
          IF np2 > 1 THEN
            FOR k := 0 TO np2 - 1 DO
              m := 0;
              FOR j := pa[k] TO pb[k] - 1 DO IF w[j] # "_" THEN part[m] := Litere.Fold(Litere.Mic(w[j])); INC(m) END END ;
              part[m] := 0X;
              IF Litere.Continut(part) & Litere.Litera(part[0]) THEN CwPune(part, -1) END
            END
          END
        END
      END
    END
  END Cuvinte;

  (* ---------- lemele ---------- *)

  PROCEDURE CautaExact(w: ARRAY OF CHAR): INTEGER;
    VAR k, r, id: INTEGER;
  BEGIN k := Litere.Hash(w) MOD HL; r := -1;
    WHILE (r < 0) & (hashL[k] # 0) DO
      id := hashL[k] - 1;
      IF NumeEq(lemA[id], lemN[id], w, FALSE) THEN r := id ELSE k := (k + 1) MOD HL END
    END ;
    RETURN r
  END CautaExact;

  PROCEDURE IdOf(w: ARRAY OF CHAR): INTEGER;
    VAR k, r, id: INTEGER;
  BEGIN k := Litere.Hash(w) MOD HL; r := -1;
    WHILE (r < 0) & (hashL[k] # 0) DO
      id := hashL[k] - 1;
      IF NumeEq(lemA[id], lemN[id], w, FALSE) THEN r := id ELSE k := (k + 1) MOD HL END
    END ;
    IF (r < 0) & (nl < MaxL) & (nl < HL DIV 2) THEN
      r := nl; NumeNou(w, lemA[r], lemN[r]); lemCnt[r] := 0; lemHead[r] := -1; lemTail[r] := -1;
      hashL[k] := r + 1; INC(nl)
    END ;
    RETURN r
  END IdOf;

  (* id-ul unui cuvant din intrebare; -1 daca nu e in memorie *)
  PROCEDURE Cauta*(cuvant: ARRAY OF CHAR): INTEGER;
    VAR l, s: ARRAY 64 OF CHAR; id, n: INTEGER;
  BEGIN Litere.Copy(cuvant, l); Litere.MicFold(l);
    id := CautaExact(l); n := Litere.Len(l);
    IF (id < 0) & (n > 4) & (l[n-1] = "s") THEN Litere.Sub(l, 0, n - 1, s); id := CautaExact(s) END ;
    IF (id < 0) & (n > 5) & (l[n-2] = "e") & (l[n-1] = "s") THEN Litere.Sub(l, 0, n - 2, s); id := CautaExact(s) END ;
    RETURN id
  END Cauta;

  PROCEDURE Posteaza(id, u: INTEGER);
  BEGIN
    IF np < MaxP THEN
      ulem[np] := id; pUnit[np] := u; pNext[np] := -1;
      IF lemHead[id] < 0 THEN lemHead[id] := np ELSE pNext[lemTail[id]] := np END ;
      lemTail[id] := np; INC(lemCnt[id]); INC(np)
    END
  END Posteaza;

  (* unitatile cu lema id, in ordine *)
  PROCEDURE Prima*(id: INTEGER): INTEGER;
  BEGIN RETURN lemHead[id]
  END Prima;

  PROCEDURE Urmatoarea*(p: INTEGER): INTEGER;
  BEGIN RETURN pNext[p]
  END Urmatoarea;

  PROCEDURE UnitP*(p: INTEGER): INTEGER;
  BEGIN RETURN pUnit[p]
  END UnitP;

  PROCEDURE Are*(u, id: INTEGER): BOOLEAN;
    VAR i: INTEGER; r: BOOLEAN;
  BEGIN r := FALSE; i := uLemA[u];
    WHILE ~r & (i < uLemA[u] + uLemN[u]) DO r := ulem[i] = id; INC(i) END ;
    RETURN r
  END Are;

  (* ---------- mancatul ---------- *)

  PROCEDURE Rang(s: ARRAY OF CHAR): INTEGER;               (* sursele mai „curate” intai *)
    VAR l: ARRAY 512 OF CHAR; r: INTEGER;
  BEGIN Litere.Copy(s, l); Litere.MicS(l);
    IF Litere.Incepe(l, "project oberon") THEN r := 0
    ELSIF (Litere.Pos("norebo", l, 0) >= 0) OR (Litere.Pos("pion", l, 0) >= 0) OR (Litere.Pos("învățat", l, 0) >= 0) OR (Litere.Pos("conversa", l, 0) >= 0) THEN r := 1
    ELSIF (Litere.Pos("/voc/src/runtime", l, 0) >= 0) OR (Litere.Pos("/voc/src/library/v4", l, 0) >= 0) THEN r := 2
    ELSE r := 3
    END ;
    RETURN r
  END Rang;

  PROCEDURE Spatiu(c: CHAR): BOOLEAN;
  BEGIN RETURN (c = " ") OR (c = 9X) OR (c = 0AX) OR (c = 0BX) OR (c = 0CX) OR (c = 0DX)
  END Spatiu;

  PROCEDURE CuvantLa(VAR t: ARRAY OF CHAR; i, lim: INTEGER; w: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER;
  BEGIN k := 0;
    WHILE (w[k] # 0X) & (i + k < lim) & (t[i+k] = w[k]) DO INC(k) END ;
    RETURN w[k] = 0X
  END CuvantLa;

  (* pare cod Oberon? (inceputul e MODULE/PROCEDURE/CONST/TYPE/VAR, sau un rand „MODULE Nume;” in primele 2000 de semne) *)
  PROCEDURE PareCod*(VAR t: ARRAY OF CHAR; len: INTEGER): BOOLEAN;
    VAR lim, i, j, ls: INTEGER; r, gata: BOOLEAN;
  BEGIN IF len > 4000 THEN lim := 4000 ELSE lim := len END ;
    i := 0; r := FALSE;
    WHILE (i < lim) & Spatiu(t[i]) DO INC(i) END ;
    gata := FALSE;
    WHILE ~gata & (i + 1 < lim) & (t[i] = "(") & (t[i+1] = "*") DO
      j := i + 2;
      WHILE (j + 1 < lim) & ~((t[j] = "*") & (t[j+1] = ")")) DO INC(j) END ;
      IF j + 1 < lim THEN i := j + 2; WHILE (i < lim) & Spatiu(t[i]) DO INC(i) END ELSE gata := TRUE END
    END ;
    IF CuvantLa(t, i, lim, "MODULE") THEN
      j := i + 6; IF (j < lim) & (t[j] = "*") THEN INC(j) END ;
      IF (j < lim) & Spatiu(t[j]) THEN
        WHILE (j < lim) & Spatiu(t[j]) DO INC(j) END ;
        r := (j < lim) & ((t[j] >= "A") & (t[j] <= "Z") OR (t[j] >= "a") & (t[j] <= "z"))
      END
    ELSIF CuvantLa(t, i, lim, "PROCEDURE") THEN r := (i + 9 < lim) & Spatiu(t[i+9])
    ELSIF CuvantLa(t, i, lim, "CONST") THEN r := (i + 5 < lim) & Spatiu(t[i+5])
    ELSIF CuvantLa(t, i, lim, "TYPE") THEN r := (i + 4 < lim) & Spatiu(t[i+4])
    ELSIF CuvantLa(t, i, lim, "VAR") THEN r := (i + 3 < lim) & Spatiu(t[i+3])
    END ;
    ls := 0;
    WHILE ~r & (ls <= 2000) & (ls < lim) DO
      IF ((ls = 0) OR (t[ls-1] = 0AX)) & CuvantLa(t, ls, lim, "MODULE") THEN
        j := ls + 6; IF (j < lim) & (t[j] = "*") THEN INC(j) END ;
        IF (j < lim) & Spatiu(t[j]) THEN
          WHILE (j < lim) & Spatiu(t[j]) DO INC(j) END ;
          IF (j < lim) & ((t[j] >= "A") & (t[j] <= "Z") OR (t[j] >= "a") & (t[j] <= "z")) THEN
            WHILE (j < lim) & Litere.Cuvant(t[j]) DO INC(j) END ;
            WHILE (j < lim) & Spatiu(t[j]) DO INC(j) END ;
            r := (j < lim) & (t[j] = ";")
          END
        END
      END ;
      INC(ls)
    END ;
    RETURN r
  END PareCod;

  PROCEDURE AdaugaUnit(r, kind: INTEGER; name: ARRAY OF CHAR; from, to, head: INTEGER; exp, curat: BOOLEAN; VAR t: ARRAY OF CHAR);
    VAR u, i, id: INTEGER; l: ARRAY 64 OF CHAR; m: ARRAY 256 OF CHAR;
  BEGIN
    IF nu < MaxU THEN
      u := nu; INC(nu);
      uRec[u] := r; uFrom[u] := from; uTo[u] := to; uHead[u] := head; uKind[u] := kind; uExp[u] := exp; uCurat[u] := curat;
      NumeNou(name, uNameA[u], uNameN[u]);
      Cuvinte(t, from, to);
      IF kind # KText THEN
        Litere.Copy(name, l); Litere.MicFold(l);
        IF (Litere.Len(l) >= 2) & ~CwContine(l) THEN CwPune(l, 0) END ;
        IF recModN[r] > 0 THEN
          ModIn(r, m); Litere.Copy(m, l); Litere.MicFold(l);
          IF (Litere.Len(l) >= 2) & ~CwContine(l) THEN IF ncw < 1 THEN CwPune(l, ncw) ELSE CwPune(l, 1) END END
        END
      END ;
      uLemA[u] := np; i := 0;
      WHILE i < ncw DO
        CwIn(i, l); id := IdOf(l);
        IF id >= 0 THEN Posteaza(id, u) END ;
        INC(i)
      END ;
      uLemN[u] := np - uLemA[u]
    END
  END AdaugaUnit;

  PROCEDURE AdaugaDecl(r, kind: INTEGER; name: ARRAY OF CHAR; from, to, level: INTEGER; exp: BOOLEAN);
    VAR x, h: INTEGER;
  BEGIN
    IF nd < MaxD THEN
      x := nd; INC(nd);
      dRec[x] := r; dKind[x] := kind; dFrom[x] := from; dTo[x] := to; dLevel[x] := level; dExp[x] := exp;
      NumeNou(name, dNameA[x], dNameN[x]);
      IF kind = KProc THEN INC(nrProc) END ;
      h := HashNume(dNameA[x], dNameN[x], TRUE) MOD HD;
      dNext[x] := hashD[h] - 1; hashD[h] := x + 1           (* listele pe nume amesteca uneori nume diferite: se verifica la cautare *)
    END
  END AdaugaDecl;

  PROCEDURE LegaModul(r: INTEGER);
    VAR h: INTEGER;
  BEGIN h := HashNume(recModA[r], recModN[r], TRUE) MOD HM;
    recNextMod[r] := hashM[h] - 1; hashM[h] := r + 1; INC(nrMod)
  END LegaModul;

  PROCEDURE Blanc(c: CHAR): BOOLEAN;
  BEGIN RETURN c <= " "
  END Blanc;

  PROCEDURE AdaugaText(r: INTEGER; VAR t: ARRAY OF CHAR; a, b, len: INTEGER);
    VAR m: INTEGER; w: ARRAY 64 OF CHAR;
  BEGIN
    WHILE (a < b) & Blanc(t[a]) DO INC(a) END ;
    WHILE (b > a) & Blanc(t[b-1]) DO DEC(b) END ;
    IF b - a >= 3 THEN
      m := -1;
      IF b - a > 900 THEN                                    (* paragrafele lungi, pe fraze *)
        m := a + 700; IF m > len - 2 THEN m := len - 2 END ;
        WHILE (m >= 0) & ~((t[m] = ".") & (t[m+1] = " ")) DO DEC(m) END ;
        IF m <= a + 200 THEN m := -1 END
      END ;
      IF m >= 0 THEN AdaugaText(r, t, a, m + 1, len); AdaugaText(r, t, m + 2, b, len)
      ELSE
        Cuvinte(t, a, b);
        IF ncw = 0 THEN w := "text" ELSE CwIn(0, w) END ;
        AdaugaUnit(r, KText, w, a, b, b, FALSE, TRUE, t)
      END
    END
  END AdaugaText;

  PROCEDURE ClasaDupa(c: CHAR): BOOLEAN;                   (* [\p{Lu}0-9„"(] *)
  BEGIN RETURN Litere.Mare(c) OR Litere.Cifra(c) OR (ORD(c) = 201EH) OR (c = 22X) OR (c = "(")
  END ClasaDupa;

  (* textul obisnuit, taiat la randurile goale si dupa . ! ? urmate de majuscula *)
  PROCEDURE Proza(r: INTEGER; VAR t: ARRAY OF CHAR; len: INTEGER);
    VAR a, i, j, k, ms, me: INTEGER;
  BEGIN a := 0; i := 0;
    WHILE i < len DO
      ms := -1;
      IF t[i] = 0AX THEN
        j := i + 1; k := -1;
        WHILE (j < len) & Spatiu(t[j]) DO IF t[j] = 0AX THEN k := j END ; INC(j) END ;
        IF k >= 0 THEN ms := i; me := k + 1 END
      END ;
      IF (ms < 0) & (i > 0) & ((t[i-1] = ".") OR (t[i-1] = "!") OR (t[i-1] = "?")) & Spatiu(t[i]) THEN
        j := i;
        WHILE (j < len) & Spatiu(t[j]) DO INC(j) END ;
        IF (j < len) & ClasaDupa(t[j]) THEN ms := i; me := j END
      END ;
      IF ms >= 0 THEN AdaugaText(r, t, a, ms, len); a := me; i := me ELSE INC(i) END
    END ;
    AdaugaText(r, t, a, len, len)
  END Proza;

  (* adauga un fisier sau o bucata de text; intoarce cate unitati noi *)
  PROCEDURE Adauga*(VAR t: ARRAY OF CHAR; len: INTEGER; src: ARRAY OF CHAR): INTEGER;
    VAR r, i, u0, from, to, head: INTEGER; s: ARRAY 600 OF CHAR; nume: ARRAY 256 OF CHAR; gol: BOOLEAN;
  BEGIN
    IF nrec < MaxRec THEN
      r := nrec; INC(nrec);
      recA[r] := T; i := 0;
      WHILE i < len DO PuneText(t[i]); IF t[i] = 0AX THEN INC(nrLinii) END ; INC(i) END ;
      recN[r] := len;
      NumeNou(src, recSrcA[r], recSrcN[r]); recRang[r] := Rang(src);
      recModA[r] := 0; recModN[r] := 0; recErrA[r] := 0; recErrN[r] := 0; recImpA[r] := nimp; recImpN[r] := 0;
      u0 := nu; recU0[r] := nu;
      IF PareCod(t, len) THEN
        Gramatica.Analizeaza(t, len);
        IF Gramatica.modN > 0 THEN
          Gramatica.Nume(Gramatica.modA, Gramatica.modN, s); NumeNou(s, recModA[r], recModN[r]); LegaModul(r)
        END ;
        i := 0;
        WHILE (i < Gramatica.nimp) & (nimp < MaxImp) DO
          Gramatica.Nume(Gramatica.impA[i], Gramatica.impN[i], s); NumeNou(s, impA[nimp], impN[nimp]); INC(nimp); INC(i)
        END ;
        recImpN[r] := nimp - recImpA[r];
        IF ~Gramatica.ok THEN recDial[r] := 2 ELSIF Gramatica.no2 = 0 THEN recDial[r] := 0 ELSE recDial[r] := 1 END ;
        IF ~Gramatica.ok THEN
          s := "linia "; Litere.AddInt(s, Gramatica.linie); Litere.Add(s, ": "); Litere.Add(s, Gramatica.eroare);
          NumeNou(s, recErrA[r], recErrN[r])
        END ;
        i := 0;
        WHILE i < Gramatica.nu DO
          from := Gramatica.uFrom[i]; to := Gramatica.uTo[i];
          IF to - from >= 2 THEN
            head := Gramatica.uHead[i]; IF head > to THEN head := to END ; IF head < from THEN head := from END ;
            Gramatica.NumeU(i, nume);
            AdaugaUnit(r, Gramatica.uKind[i], nume, from, to, head, Gramatica.uExp[i], Gramatica.uCurat[i] & Gramatica.ok, t)
          END ;
          INC(i)
        END ;
        IF nu = u0 THEN
          gol := TRUE; i := 0;
          WHILE gol & (i < len) DO gol := t[i] <= " "; INC(i) END ;
          IF ~gol THEN
            IF recModN[r] > 0 THEN ModIn(r, nume) ELSE nume := "fragment" END ;
            AdaugaUnit(r, KText, nume, 0, len, len, FALSE, Gramatica.ok, t)
          END
        END ;
        i := 0;
        WHILE i < Gramatica.nd DO
          Gramatica.Nume(Gramatica.dNameA[i], Gramatica.dNameN[i], nume);
          AdaugaDecl(r, Gramatica.dKind[i], nume, Gramatica.dFrom[i], Gramatica.dTo[i], Gramatica.dLevel[i], Gramatica.dExp[i]);
          INC(i)
        END
      ELSE
        recDial[r] := 3;
        Proza(r, t, len)
      END ;
      recU1[r] := nu
    END ;
    RETURN nu - u0
  END Adauga;

  (* ---------- citit ---------- *)

  PROCEDURE Lungime*(u: INTEGER): INTEGER;
  BEGIN RETURN uTo[u] - uFrom[u]
  END Lungime;

  PROCEDURE UCh*(u, i: INTEGER): CHAR;                    (* semnul i din unitatea u *)
  BEGIN RETURN RCh(uRec[u], uFrom[u] + i)
  END UCh;

  (* cele doua unitati au acelasi text? *)
  PROCEDURE AcelasiText*(a, b: INTEGER): BOOLEAN;
    VAR i, n: INTEGER; r: BOOLEAN;
  BEGIN n := Lungime(a); r := n = Lungime(b); i := 0;
    WHILE r & (i < n) DO r := UCh(a, i) = UCh(b, i); INC(i) END ;
    RETURN r
  END AcelasiText;

  PROCEDURE Inainte(a, b: INTEGER; nume: ARRAY OF CHAR): BOOLEAN;   (* a vine inaintea lui b? *)
    VAR ea, eb: BOOLEAN; c: INTEGER;
  BEGIN ea := NumeEq(dNameA[a], dNameN[a], nume, FALSE); eb := NumeEq(dNameA[b], dNameN[b], nume, FALSE);
    IF ea # eb THEN c := 0; IF ea THEN c := -1 ELSE c := 1 END
    ELSIF dLevel[a] # dLevel[b] THEN c := dLevel[a] - dLevel[b]
    ELSIF dExp[a] # dExp[b] THEN IF dExp[a] THEN c := -1 ELSE c := 1 END
    ELSIF recRang[dRec[a]] # recRang[dRec[b]] THEN c := recRang[dRec[a]] - recRang[dRec[b]]
    ELSE c := a - b
    END ;
    RETURN c < 0
  END Inainte;

  (* declaratiile cu un nume (fara sa conteze literele mari); modul = "" pentru oricare.
     Ordinea: numele exact intai, apoi nivelul modulului, cele exportate, sursele curate, cele mai vechi *)
  PROCEDURE Declaratii*(nume, modul: ARRAY OF CHAR; VAR l: ARRAY OF INTEGER; VAR k: INTEGER);
    VAR mic, mm, m: ARRAY 256 OF CHAR; h, x, i, j, y: INTEGER; ia: BOOLEAN;


  BEGIN k := 0; Litere.Copy(nume, mic); Litere.MicS(mic); Litere.Copy(modul, mm); Litere.MicS(mm);
    h := Litere.Hash(mic) MOD HD; x := hashD[h] - 1;
    WHILE x >= 0 DO
      IF NumeEq(dNameA[x], dNameN[x], mic, TRUE) THEN
        ia := TRUE;
        IF modul[0] # 0X THEN
          ModIn(dRec[x], m); Litere.MicS(m);
          ia := (recModN[dRec[x]] > 0) & (m = mm)
        END ;
        IF ia & (k < LEN(l)) THEN l[k] := x; INC(k) END
      END ;
      x := dNext[x]
    END ;
    i := 1;
    WHILE i < k DO
      y := l[i]; j := i;
      WHILE (j > 0) & Inainte(y, l[j-1], nume) DO l[j] := l[j-1]; DEC(j) END ;
      l[j] := y; INC(i)
    END
  END Declaratii;

  (* fisierele cu modulul numit asa, in ordinea in care au fost mancate *)
  PROCEDURE Module*(nume: ARRAY OF CHAR; VAR l: ARRAY OF INTEGER; VAR k: INTEGER);
    VAR mic: ARRAY 256 OF CHAR; r, i, x: INTEGER;
  BEGIN k := 0; Litere.Copy(nume, mic); Litere.MicS(mic);
    r := hashM[Litere.Hash(mic) MOD HM] - 1;
    WHILE r >= 0 DO
      IF NumeEq(recModA[r], recModN[r], mic, TRUE) & (k < LEN(l)) THEN l[k] := r; INC(k) END ;
      r := recNextMod[r]
    END ;
    i := 0;                                                  (* lista vine de la cel mai nou: o intorc *)
    WHILE i < k DIV 2 DO x := l[i]; l[i] := l[k-1-i]; l[k-1-i] := x; INC(i) END
  END Module;

  (* unitatea care contine o declaratie (cea mai mica din fisierul ei) *)
  PROCEDURE UnitDe*(x: INTEGER): INTEGER;
    VAR u, best, r: INTEGER;
  BEGIN best := -1; r := dRec[x]; u := recU0[r];
    WHILE u < recU1[r] DO
      IF (uFrom[u] <= dFrom[x]) & (uTo[u] >= dTo[x]) & ((best < 0) OR (Lungime(u) < Lungime(best))) THEN best := u END ;
      INC(u)
    END ;
    RETURN best
  END UnitDe;

  PROCEDURE CuvLa(r, pos, lim: INTEGER; s: ARRAY OF CHAR): BOOLEAN;
    VAR k: INTEGER;
  BEGIN k := 0;
    WHILE (s[k] # 0X) & (pos + k < lim) & (RCh(r, pos + k) = s[k]) DO INC(k) END ;
    RETURN s[k] = 0X
  END CuvLa;

  (* apare in unitatea u numele (Modul.Nume daca modul # "") ca un cuvant intreg? *)
  PROCEDURE Gaseste*(u: INTEGER; modul, nume: ARRAY OF CHAR): BOOLEAN;
    VAR r, a, b, i, j, ln, lm: INTEGER; ok: BOOLEAN;
  BEGIN r := uRec[u]; a := uFrom[u]; b := uTo[u]; ln := Litere.Len(nume); lm := Litere.Len(modul);
    ok := FALSE; i := a;
    WHILE ~ok & (i < b) DO
      IF ((i = a) OR ~Litere.Cuvant(RCh(r, i - 1))) THEN
        IF lm > 0 THEN
          IF CuvLa(r, i, b, modul) THEN
            j := i + lm;
            WHILE (j < b) & Spatiu(RCh(r, j)) DO INC(j) END ;
            IF (j < b) & (RCh(r, j) = ".") THEN
              INC(j);
              WHILE (j < b) & Spatiu(RCh(r, j)) DO INC(j) END ;
              ok := CuvLa(r, j, b, nume) & ((j + ln = b) OR ~Litere.Cuvant(RCh(r, j + ln)))
            END
          END
        ELSE ok := CuvLa(r, i, b, nume) & ((i + ln = b) OR ~Litere.Cuvant(RCh(r, i + ln)))
        END
      END ;
      INC(i)
    END ;
    RETURN ok
  END Gaseste;

  (* unitatile in care apare un nume (Modul.Nume daca modul # "") *)
  PROCEDURE Folosiri*(nume, modul: ARRAY OF CHAR; VAR l: ARRAY OF INTEGER; VAR k: INTEGER);
    VAR id, p, u: INTEGER; f: ARRAY 256 OF CHAR;
  BEGIN k := 0; id := Cauta(nume);
    Litere.Copy(nume, f); Litere.MicFold(f);
    IF (id >= 0) & ~Litere.Continut(f) THEN id := -1 END ;   (* „This”, „Old”: caut peste tot *)
    IF id >= 0 THEN p := lemHead[id] ELSE p := 0 END ;
    WHILE ((id >= 0) & (p >= 0) OR (id < 0) & (p < nu)) & (k < LEN(l)) DO
      IF id >= 0 THEN u := pUnit[p] ELSE u := p END ;
      IF ~((uKind[u] = KText) & (recModN[uRec[u]] = 0)) & Gaseste(u, modul, nume) THEN l[k] := u; INC(k) END ;
      IF id >= 0 THEN p := pNext[p] ELSE INC(p) END
    END
  END Folosiri;

  PROCEDURE NrModule*(): INTEGER;
  BEGIN RETURN nrMod
  END NrModule;

  PROCEDURE NrProceduri*(): INTEGER;
  BEGIN RETURN nrProc
  END NrProceduri;

  PROCEDURE NrLinii*(): INTEGER;
  BEGIN RETURN nrLinii
  END NrLinii;

  (* ---------- fotografia: memoria gata taiata si indexata, pentru pornirea rapida ---------- *)

  PROCEDURE Goleste*;
    VAR i: INTEGER;
  BEGIN T := 0; NP := 0; nrec := 0; nimp := 0; nu := 0; nd := 0; nl := 0; np := 0; nrMod := 0; nrProc := 0; nrLinii := 0;
    FOR i := 0 TO HL - 1 DO hashL[i] := 0 END ;
    FOR i := 0 TO HD - 1 DO hashD[i] := 0 END ;
    FOR i := 0 TO HM - 1 DO hashM[i] := 0 END
  END Goleste;

  PROCEDURE Salveaza*(cale, cheie: ARRAY OF CHAR): BOOLEAN;
    VAR i: INTEGER; tmp: ARRAY 1024 OF CHAR; ok: BOOLEAN;
  BEGIN Litere.Copy(cale, tmp); Litere.Add(tmp, ".tmp"); ok := FALSE;
    IF Disc.Scrie(tmp) THEN
      Disc.PuneInt(MAGIC); Disc.PuneInt(VER); Disc.PuneSir(cheie);
      Disc.PuneInt(T); FOR i := 0 TO T - 1 DO Disc.PuneCh(Ch(i)) END ;
      Disc.PuneInt(NP); FOR i := 0 TO NP - 1 DO Disc.PuneCh(PCh(i)) END ;
      Disc.PuneInt(nrec);
      FOR i := 0 TO nrec - 1 DO
        Disc.PuneInt(recA[i]); Disc.PuneInt(recN[i]); Disc.PuneInt(recSrcA[i]); Disc.PuneInt(recSrcN[i]);
        Disc.PuneInt(recModA[i]); Disc.PuneInt(recModN[i]); Disc.PuneInt(recDial[i]); Disc.PuneInt(recErrA[i]); Disc.PuneInt(recErrN[i]);
        Disc.PuneInt(recImpA[i]); Disc.PuneInt(recImpN[i]); Disc.PuneInt(recU0[i]); Disc.PuneInt(recU1[i]); Disc.PuneInt(recRang[i])
      END ;
      Disc.PuneInt(nimp); FOR i := 0 TO nimp - 1 DO Disc.PuneInt(impA[i]); Disc.PuneInt(impN[i]) END ;
      Disc.PuneInt(nl); FOR i := 0 TO nl - 1 DO Disc.PuneInt(lemA[i]); Disc.PuneInt(lemN[i]) END ;
      Disc.PuneInt(np); FOR i := 0 TO np - 1 DO Disc.PuneInt(ulem[i]) END ;
      Disc.PuneInt(nu);
      FOR i := 0 TO nu - 1 DO
        Disc.PuneInt(uRec[i]); Disc.PuneInt(uFrom[i]); Disc.PuneInt(uTo[i]); Disc.PuneInt(uHead[i]); Disc.PuneInt(uKind[i]);
        Disc.PuneInt(uNameA[i]); Disc.PuneInt(uNameN[i]); Disc.PuneInt(uLemA[i]); Disc.PuneInt(uLemN[i]);
        Disc.PuneBool(uExp[i]); Disc.PuneBool(uCurat[i])
      END ;
      Disc.PuneInt(nd);
      FOR i := 0 TO nd - 1 DO
        Disc.PuneInt(dRec[i]); Disc.PuneInt(dFrom[i]); Disc.PuneInt(dTo[i]); Disc.PuneInt(dKind[i]); Disc.PuneInt(dLevel[i]);
        Disc.PuneInt(dNameA[i]); Disc.PuneInt(dNameN[i]); Disc.PuneBool(dExp[i])
      END ;
      Disc.PuneInt(MAGIC);
      Disc.Inchide;
      ok := Disc.ok & Disc.Redenumeste(tmp, cale)
    END ;
    RETURN ok
  END Salveaza;

  PROCEDURE Incarca*(cale, cheie: ARRAY OF CHAR): BOOLEAN;
    VAR i, j, n, h, id: INTEGER; c: ARRAY 256 OF CHAR; ok: BOOLEAN;
  BEGIN ok := FALSE; Goleste;
    IF Disc.Citeste(cale) THEN
      IF (Disc.IaInt() = MAGIC) & (Disc.IaInt() = VER) THEN
        Disc.IaSir(c);
        IF c = cheie THEN
          n := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < n) DO PuneText(Disc.IaCh()); INC(i) END ;
          n := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < n) DO PuneNume(Disc.IaCh()); INC(i) END ;
          nrec := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < nrec) DO
            recA[i] := Disc.IaInt(); recN[i] := Disc.IaInt(); recSrcA[i] := Disc.IaInt(); recSrcN[i] := Disc.IaInt();
            recModA[i] := Disc.IaInt(); recModN[i] := Disc.IaInt(); recDial[i] := Disc.IaInt(); recErrA[i] := Disc.IaInt(); recErrN[i] := Disc.IaInt();
            recImpA[i] := Disc.IaInt(); recImpN[i] := Disc.IaInt(); recU0[i] := Disc.IaInt(); recU1[i] := Disc.IaInt(); recRang[i] := Disc.IaInt();
            IF recModN[i] > 0 THEN LegaModul(i) END ;
            INC(i)
          END ;
          nimp := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < nimp) DO impA[i] := Disc.IaInt(); impN[i] := Disc.IaInt(); INC(i) END ;
          nl := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < nl) DO
            lemA[i] := Disc.IaInt(); lemN[i] := Disc.IaInt(); lemCnt[i] := 0; lemHead[i] := -1; lemTail[i] := -1;
            h := HashNume(lemA[i], lemN[i], FALSE) MOD HL;
            WHILE hashL[h] # 0 DO h := (h + 1) MOD HL END ;
            hashL[h] := i + 1; INC(i)
          END ;
          n := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < n) DO ulem[i] := Disc.IaInt(); INC(i) END ;
          nu := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < nu) DO
            uRec[i] := Disc.IaInt(); uFrom[i] := Disc.IaInt(); uTo[i] := Disc.IaInt(); uHead[i] := Disc.IaInt(); uKind[i] := Disc.IaInt();
            uNameA[i] := Disc.IaInt(); uNameN[i] := Disc.IaInt(); uLemA[i] := Disc.IaInt(); uLemN[i] := Disc.IaInt();
            uExp[i] := Disc.IaBool(); uCurat[i] := Disc.IaBool();
            j := uLemA[i];                                   (* listele de unitati ale lemelor se refac *)
            WHILE j < uLemA[i] + uLemN[i] DO
              id := ulem[j]; pUnit[j] := i; pNext[j] := -1;
              IF lemHead[id] < 0 THEN lemHead[id] := j ELSE pNext[lemTail[id]] := j END ;
              lemTail[id] := j; INC(lemCnt[id]); INC(j)
            END ;
            INC(i)
          END ;
          np := n;
          nd := Disc.IaInt(); i := 0;
          WHILE Disc.ok & (i < nd) DO
            dRec[i] := Disc.IaInt(); dFrom[i] := Disc.IaInt(); dTo[i] := Disc.IaInt(); dKind[i] := Disc.IaInt(); dLevel[i] := Disc.IaInt();
            dNameA[i] := Disc.IaInt(); dNameN[i] := Disc.IaInt(); dExp[i] := Disc.IaBool();
            IF dKind[i] = KProc THEN INC(nrProc) END ;
            h := HashNume(dNameA[i], dNameN[i], TRUE) MOD HD;
            dNext[i] := hashD[h] - 1; hashD[h] := i + 1;
            INC(i)
          END ;
          ok := Disc.ok & (Disc.IaInt() = MAGIC);
          IF ok THEN
            FOR i := 0 TO T - 1 DO IF Ch(i) = 0AX THEN INC(nrLinii) END END
          END
        END
      END ;
      Disc.Inchide
    END ;
    IF ~ok THEN Goleste END ;
    RETURN ok
  END Incarca;

BEGIN T := 0; NP := 0; nrec := 0; nimp := 0; nu := 0; nd := 0; nl := 0; np := 0; stamp := 0;
  nrMod := 0; nrProc := 0; nrLinii := 0;
  kw[0] := "ARRAY"; kw[1] := "BEGIN"; kw[2] := "BY"; kw[3] := "CASE"; kw[4] := "CONST"; kw[5] := "DIV"; kw[6] := "DO";
  kw[7] := "ELSE"; kw[8] := "ELSIF"; kw[9] := "END"; kw[10] := "EXIT"; kw[11] := "FOR"; kw[12] := "IF"; kw[13] := "IMPORT";
  kw[14] := "IN"; kw[15] := "IS"; kw[16] := "LOOP"; kw[17] := "MOD"; kw[18] := "MODULE"; kw[19] := "NIL"; kw[20] := "OF";
  kw[21] := "OR"; kw[22] := "POINTER"; kw[23] := "PROCEDURE"; kw[24] := "RECORD"; kw[25] := "REPEAT"; kw[26] := "RETURN";
  kw[27] := "THEN"; kw[28] := "TO"; kw[29] := "TYPE"; kw[30] := "UNTIL"; kw[31] := "VAR"; kw[32] := "WHILE"; kw[33] := "WITH"
END Memorie.
