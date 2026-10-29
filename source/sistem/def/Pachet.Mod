(* Pachet: face o aplicatie Android (APK) dintr-un modul Oberon care exporta Deseneaza (si, daca vrea, Atinge),
   sau dintr-o pagina HTML (Html, Toate: pielea WebView + pagina ta, plus un zip pentru itch.io).
   Manifestul binar, arhiva si semnatura le scrie Eula singura. Implementat in Java (sistem/java/Pachet.java). *)
DEFINITION Pachet;
  PROCEDURE Fa(fisier, eticheta: ARRAY OF CHAR): BOOLEAN;  (* eticheta "" = numele modulului *)
  PROCEDURE FaCuEula(fisier, eticheta: ARRAY OF CHAR): BOOLEAN;  (* v29: la fel, plus toata Eula Oberon inauntru
                                                            (codul, Inferno, terminalul, assets), alt pachet: ...eula *)
  PROCEDURE Ultimul(VAR apk: ARRAY OF CHAR);                (* calea APK-ului facut ultima data *)
  PROCEDURE Instaleaza(apk: ARRAY OF CHAR);                 (* ii cere Android-ului sa-l instaleze *)
  PROCEDURE Html(fisier, eticheta: ARRAY OF CHAR): BOOLEAN; (* o pagina HTML -> aplicatie + zip pentru itch.io *)
  PROCEDURE Toate(): INTEGER;                               (* toate paginile din Download/html; cate au iesit *)
  PROCEDURE Acces;                                          (* cere voie la fisierele telefonului (Download) *)
END Pachet.
