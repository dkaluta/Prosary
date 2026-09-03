//
//  PrayerTranslations+Spanish.swift
//  Prosary
//
//  Sourced, not composed: every prayer below is the text in the appendix of the Holy See's own
//  Spanish Compendium of the Catechism ("Oraciones comunes"), which prints each one beside its
//  Latin twin — so the wording was checked against the Latin this app already ships rather than
//  against memory. Line breaks follow the Compendium's own layout.
//  <https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_sp.html>
//
//  Deliberately absent, falling back to Latin per key: the Apostles' Creed, the Fatima Prayer,
//  the St. Michael prayer, Alma Redemptoris Mater, Ave Regina Caelorum and the Jesus Prayer.
//  The Compendium's appendix does not carry them, and a prayer a community actually recites is
//  not something to reconstruct — the same rule the Greek table follows.
//
//  Scripture in Spanish comes from Félix Torres Amat's 1836 Bible, translated from the Vulgate,
//  which is why no versification map is needed — see Shared/tools/import-scripture.py.
//

import Foundation

extension PrayerTranslations {
  static let spanish: [PrayerKey: String] = [
    .signumCrucis:
      "En el nombre del Padre ✠ y del Hijo y del Espíritu Santo. Amén.",

    .paterNoster:
      "Padre nuestro que estás en el cielo, santificado sea tu Nombre;\n" +
      "venga a nosotros tu Reino; hágase tu voluntad\n" +
      "en la tierra como en el cielo.\n" +
      "Danos hoy nuestro pan de cada día;\n" +
      "perdona nuestras ofensas,\n" +
      "como también nosotros perdonamos a los que nos ofenden;\n" +
      "no nos dejes caer en la tentación,\n" +
      "y líbranos del mal. Amén.",

    .aveMaria:
      "Dios te salve, María, llena eres de gracia;\n" +
      "el Señor es contigo.\n" +
      "Bendita Tú eres entre todas las mujeres,\n" +
      "y bendito es el fruto de tu vientre, Jesús.\n" +
      "Santa María, Madre de Dios,\n" +
      "ruega por nosotros, pecadores,\n" +
      "ahora y en la hora de nuestra muerte. Amén.",

    .gloriaPatri:
      "Gloria al Padre y al Hijo y al Espíritu Santo.\n" +
      "Como era en el principio, ahora y siempre,\n" +
      "por los siglos de los siglos. Amén.",

    .requiemAeternam:
      "Dale Señor el descanso eterno.\n" +
      "Brille para él la luz perpetua.\n" +
      "Descanse en paz.\n" +
      "Amén.",

    .subTuumPraesidiumTitle: "Bajo tu amparo",

    .subTuumPraesidium:
      "Bajo tu amparo nos acogemos,\n" +
      "Santa Madre de Dios;\n" +
      "no deseches las súplicas que te dirigimos en nuestras necesidades;\n" +
      "antes bien, líbranos siempre de todo peligro,\n" +
      "¡Oh Virgen gloriosa y bendita!",

    .salveReginaTitle: "Dios te salve, Reina",

    .salveRegina:
      "Dios te salve, Reina y Madre de misericordia,\n" +
      "vida, dulzura y esperanza nuestra; Dios te salve.\n" +
      "A ti llamamos los desterrados hijos de Eva;\n" +
      "a ti suspiramos, gimiendo y llorando en este valle de lágrimas.\n" +
      "Ea, pues, Señora, abogada nuestra,\n" +
      "vuelve a nosotros esos tus ojos misericordiosos;\n" +
      "y después de este destierro, muéstranos a Jesús,\n" +
      "fruto bendito de tu vientre.\n" +
      "¡Oh clementísima, oh piadosa, oh dulce Virgen María!",

    .reginaCaeliTitle: "Reina del cielo",

    .reginaCaeli:
      "Reina del cielo alégrate; aleluya.\n" +
      "Porque el Señor a quien has merecido llevar; aleluya.\n" +
      "Ha resucitado según su palabra; aleluya.\n" +
      "Ruega al Señor por nosotros; aleluya.",

    .animaChristi:
      "Alma de Cristo, santifícame.\n" +
      "Cuerpo de Cristo, sálvame.\n" +
      "Sangre de Cristo, embriágame.\n" +
      "Agua del costado de Cristo, lávame.\n" +
      "Pasión de Cristo, confórtame.\n" +
      "¡Oh, buen Jesús!, óyeme.\n" +
      "Dentro de tus llagas, escóndeme.\n" +
      "No permitas que me aparte de Ti.\n" +
      "Del maligno enemigo, defiéndeme.\n" +
      "En la hora de mi muerte, llámame.\n" +
      "Y mándame ir a Ti.\n" +
      "Para que con tus santos te alabe.\n" +
      "Por los siglos de los siglos. Amén.",

    // The Compendium prints these under "Oración tras el rosario" — the Rosary's own versicle,
    // response and collect, not the Angelus's.
    .versiculumStandard: "Ruega por nosotros, Santa Madre de Dios.",
    .responsiumStandard: "Para que seamos dignos de alcanzar las promesas de Nuestro Señor Jesucristo.",
    .collectaStandard:
      "Oremos. Oh Dios, cuyo Hijo por medio de su vida, muerte y resurrección, nos otorgó los " +
      "premios de la vida eterna, te rogamos que venerando humildemente los misterios del " +
      "Rosario de la Santísima Virgen María, imitemos lo que contienen y consigamos lo que nos " +
      "prometen. Por Jesucristo, nuestro Señor. Amén.",

    .versiculumPaschale: "Gózate y alégrate, Virgen María; aleluya.",
    .responsiumPaschale: "Porque verdaderamente ha resucitado el Señor; aleluya.",
    .collectaPaschale:
      "Oremos. Oh Dios, que por la resurrección de tu Hijo, nuestro Señor Jesucristo, has " +
      "llenado el mundo de alegría, concédenos, por intercesión de su Madre, la Virgen María, " +
      "llegar a alcanzar los gozos eternos. Por nuestro Señor Jesucristo. Amén.",

    .aveMariaProFide: "Dios te salve, María — por el aumento de la fe.",
    .aveMariaProSpe: "Dios te salve, María — por el aumento de la esperanza.",
    .aveMariaProCaritate: "Dios te salve, María — por el aumento de la caridad.",

    .decadeOrdinalFormat: "{noun} {n}",

    .repetitionCounterConnector: "de",

    .fructusMysteriiLabel: "Fruto del Misterio",
  ]
}
