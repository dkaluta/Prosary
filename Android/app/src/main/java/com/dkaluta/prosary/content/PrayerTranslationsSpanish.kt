package com.dkaluta.prosary.content

/** Sourced, not composed: every prayer here is the text in the appendix of the Holy See's own
 * Spanish Compendium of the Catechism ("Oraciones comunes"), which prints each one beside its Latin
 * twin — so the wording was checked against the Latin this app already ships rather than against
 * memory. Deliberately absent, falling back to Latin per key: the Apostles' Creed, the Fatima
 * Prayer, the St. Michael prayer, Alma Redemptoris Mater, Ave Regina Caelorum and the Jesus Prayer,
 * none of which the appendix carries. Generated from the Swift table so the three cannot drift. */
val prayerTranslationsSpanish: Map<PrayerKey, String> = mapOf(
    PrayerKey.SignumCrucis to
        "En el nombre del Padre ✠ y del Hijo y del Espíritu Santo. Amén.",
    PrayerKey.PaterNoster to
        "Padre nuestro que estás en el cielo,\n" +
            "santificado sea tu Nombre;\n" +
            "venga a nosotros tu Reino;\n" +
            "hágase tu voluntad en la tierra como en el cielo.\n" +
            "Danos hoy nuestro pan de cada día;\n" +
            "perdona nuestras ofensas,\n" +
            "como también nosotros perdonamos a los que nos ofenden;\n" +
            "no nos dejes caer en la tentación,\n" +
            "y líbranos del mal. Amén.",
    PrayerKey.AveMaria to
        "Dios te salve, María, llena eres de gracia;\n" +
            "el Señor es contigo.\n" +
            "Bendita Tú eres entre todas las mujeres,\n" +
            "y bendito es el fruto de tu vientre, Jesús.\n" +
            "Santa María, Madre de Dios,\n" +
            "ruega por nosotros, pecadores,\n" +
            "ahora y en la hora de nuestra muerte. Amén.",
    PrayerKey.GloriaPatri to
        "Gloria al Padre y al Hijo y al Espíritu Santo.\n" +
            "Como era en el principio, ahora y siempre,\n" +
            "por los siglos de los siglos. Amén.",
    PrayerKey.RequiemAeternam to
        "Dale Señor el descanso eterno.\n" +
            "Brille para él la luz perpetua.\n" +
            "Descanse en paz. Amén.",
    PrayerKey.SubTuumPraesidiumTitle to
        "Bajo tu amparo",
    PrayerKey.SubTuumPraesidium to
        "Bajo tu amparo nos acogemos, Santa Madre de Dios;\n" +
            "no deseches las súplicas que te dirigimos en nuestras necesidades;\n" +
            "antes bien, líbranos siempre de todo peligro,\n" +
            "¡Oh Virgen gloriosa y bendita!",
    PrayerKey.SalveReginaTitle to
        "Dios te salve, Reina",
    PrayerKey.SalveRegina to
        "Dios te salve, Reina y Madre de misericordia,\n" +
            "vida, dulzura y esperanza nuestra; Dios te salve.\n" +
            "A ti llamamos los desterrados hijos de Eva;\n" +
            "a ti suspiramos, gimiendo y llorando en este valle de lágrimas.\n" +
            "Ea, pues, Señora, abogada nuestra,\n" +
            "vuelve a nosotros esos tus ojos misericordiosos;\n" +
            "y después de este destierro, muéstranos a Jesús,\n" +
            "fruto bendito de tu vientre.\n" +
            "¡Oh clementísima, oh piadosa, oh dulce Virgen María!",
    PrayerKey.ReginaCaeliTitle to
        "Reina del cielo",
    PrayerKey.ReginaCaeli to
        "Reina del cielo alégrate; aleluya.\n" +
            "Porque el Señor a quien has merecido llevar; aleluya.\n" +
            "Ha resucitado según su palabra; aleluya.\n" +
            "Ruega al Señor por nosotros; aleluya.",
    PrayerKey.AnimaChristi to
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
    PrayerKey.VersiculumStandard to
        "Ruega por nosotros, Santa Madre de Dios.",
    PrayerKey.ResponsiumStandard to
        "Para que seamos dignos de alcanzar las promesas de Nuestro Señor Jesucristo.",
    PrayerKey.CollectaStandard to
        "Oremos. Oh Dios, cuyo Hijo por medio de su vida, muerte y resurrección, nos otorgó los premios de la vida eterna, te rogamos que venerando humildemente los misterios del Rosario de la Santísima Virgen María, imitemos lo que contienen y consigamos lo que nos prometen. Por Jesucristo, nuestro Señor. Amén.",
    PrayerKey.VersiculumPaschale to
        "Gózate y alégrate, Virgen María; aleluya.",
    PrayerKey.ResponsiumPaschale to
        "Porque verdaderamente ha resucitado el Señor; aleluya.",
    PrayerKey.CollectaPaschale to
        "Oremos. Oh Dios, que por la resurrección de tu Hijo, nuestro Señor Jesucristo, has llenado el mundo de alegría, concédenos, por intercesión de su Madre, la Virgen María, llegar a alcanzar los gozos eternos. Por nuestro Señor Jesucristo. Amén.",
    PrayerKey.AveMariaProFide to
        "Dios te salve, María — por el aumento de la fe.",
    PrayerKey.AveMariaProSpe to
        "Dios te salve, María — por el aumento de la esperanza.",
    PrayerKey.AveMariaProCaritate to
        "Dios te salve, María — por el aumento de la caridad.",
    PrayerKey.DecadeOrdinalFormat to
        "{noun} {n}",
    PrayerKey.RepetitionCounterConnector to
        "de",
    PrayerKey.FructusMysteriiLabel to
        "Fruto del Misterio",
)
