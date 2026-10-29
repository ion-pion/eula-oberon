MODULE Aplicatie;  (* aplicatii Android facute din module Oberon:  apk Busola2.Mod ["Nume"]   instaleaza X.apk
                     si din pagini HTML:  html (toate din Download/html)   html Orga.html ["Nume"] *)
  IMPORT Out, Param, Pachet;

  CONST N = 1024;

  PROCEDURE Fa*;   (* apk Fisier.Mod ["Eticheta"] [eula]: construieste aplicatia si o da la instalat;
                      v29: cu eula la sfarsit, aplicatia o are inauntru si pe toata Eula Oberon *)
    VAR f, e, apk, x: ARRAY N OF CHAR;
  BEGIN
    IF Param.Nr() = 0 THEN
      Out.String("folosire: apk Fisier.Mod [Nume] [eula]   (Nume = ce scrie sub iconita; eula = cu toata Eula Oberon inauntru)"); Out.Ln;
      Out.String("modulul exporta PROCEDURE Deseneaza* (si poate Atinge*), deseneaza cu Ecran"); Out.Ln
    ELSE
      Param.Str(0, f);
      IF Param.Nr() > 1 THEN Param.Str(1, e) ELSE e := "" END;
      IF Param.Nr() > 2 THEN Param.Str(2, x) ELSE x := "" END;
      IF (Param.Nr() = 2) & (e = "eula") THEN e := ""; x := "eula" END;   (* apk X.Mod eula *)
      IF x = "eula" THEN
        IF Pachet.FaCuEula(f, e) THEN Pachet.Ultimul(apk); Pachet.Instaleaza(apk) END
      ELSIF x # "" THEN Out.String("al treilea cuvant poate fi doar eula (apk X.Mod Nume eula)"); Out.Ln
      ELSIF Pachet.Fa(f, e) THEN Pachet.Ultimul(apk); Pachet.Instaleaza(apk)
      END
    END
  END Fa;

  PROCEDURE Html*;   (* html: toate paginile din Download/html;  html Fisier.html ["Nume"]: una, si o da la instalat *)
    VAR f, e, apk: ARRAY N OF CHAR; n: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN n := Pachet.Toate()
    ELSE
      Param.Str(0, f);
      IF Param.Nr() > 1 THEN Param.Str(1, e) ELSE e := "" END;
      IF Pachet.Html(f, e) THEN Pachet.Ultimul(apk); Pachet.Instaleaza(apk) END
    END
  END Html;

  PROCEDURE Acces*;   (* acces: Eula iti cere voie la fisierele telefonului (Download) *)
  BEGIN Pachet.Acces
  END Acces;

  PROCEDURE Instaleaza*;   (* instaleaza X.apk *)
    VAR a: ARRAY N OF CHAR;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: instaleaza Aplicatia.apk"); Out.Ln
    ELSE Param.Str(0, a); Pachet.Instaleaza(a)
    END
  END Instaleaza;

END Aplicatie.
