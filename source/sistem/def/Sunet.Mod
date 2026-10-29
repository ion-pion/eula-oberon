(* Sunet: sunetul aplicatiilor facute cu Aplicatie.Fa (apk X.Mod). Merge doar intr-o aplicatie (nu in terminal).
   Un mic sintetizator de clopotei (Nota), plus sunetul facut de tine in Oberon (Reda): pana la 8 + 16 deodata (16 din v19).
   Din v18 sunetul e stereo: NotaPan si RedaPan asaza fiecare sunet intre stanga si dreapta.
   Din v19 are si reverb (ecoul unei sali) peste tot: Reverb(procent).
   Implementat in Java (aplicatie/java/Sunet.java, AudioTrack). *)
DEFINITION Sunet;
  PROCEDURE Nota(hz, ms, volum: INTEGER);   (* o nota: frecventa in Hz, cat tine (ms), volum 0..100 *)
  PROCEDURE Reda(b: ARRAY OF REAL; n, volum: INTEGER);   (* n esantioane calculate in Oberon, pe scara de 16 biti
                                                          (ca la play: +-32767), 44100 pe secunda; se amesteca cu restul *)
  PROCEDURE NotaPan(hz, ms, volum, pan: INTEGER);           (* ca Nota, dar asezata intre stanga si dreapta:
                                                             pan -100 = stanga, 0 = mijloc, 100 = dreapta (v18) *)
  PROCEDURE RedaPan(b: ARRAY OF REAL; n, volum, pan: INTEGER);   (* ca Reda, cu pan -100 .. 100 (se aude in casti) *)
  PROCEDURE Reverb(procent: INTEGER);       (* ecoul unei sali peste tot sunetul: 0 = uscat, 100 = sala mare (v19) *)
  PROCEDURE Voce(hz: REAL; volum: INTEGER);   (* vocea continua: o chemi la fiecare cadru; alunecă lin spre hz
                                               si spre volum (0 = tace). Ton Shepard: aceeasi nota in mai multe
                                               octave deodata, deci poate urca sau cobori la nesfarsit, fara salt *)
  PROCEDURE Timbru(t: INTEGER);              (* vocea continua: 0 sin, 1 saw, 2 patrat, 3 triunghi *)
  PROCEDURE Liniste;                         (* opreste tot ce suna *)
  PROCEDURE Ms(): INTEGER;                   (* milisecunde de cand a pornit aplicatia: ceasul pentru ritm *)
END Sunet.
