package com.dkaluta.prosary.content

/** Liturgical Greek, polytonic. Deliberately partial: the keys here are prayers whose *original*
 * language is Greek (the Creed as the Council wrote it, the Sub Tuum on Rylands Papyrus 470, the
 * Jesus Prayer, the doxology) or plain UI labels. The Latin-tradition prayers — Salve Regina, Alma
 * Redemptoris Mater, Ave Regina Caelorum, Regina Caeli, the Fatima Prayer, the St. Michael prayer,
 * Eternal Rest, Anima Christi, both collects — are absent on purpose. Greek renderings exist in
 * Greek Catholic use, but searching Greek Wikisource and the Catholic Church in Greece turned up
 * none this app can cite, and PrayerTranslations falls back to Latin per key. An invented
 * translation of a prayer a community actually recites is worse than the honest fallback.
 * Generated from the Swift table by a one-off port so the three platforms cannot drift. */
val prayerTranslationsGreek: Map<PrayerKey, String> = mapOf(
    PrayerKey.SignumCrucis to
        "Εἰς τὸ ὄνομα τοῦ Πατρὸς ✠ καὶ τοῦ Υἱοῦ καὶ τοῦ Ἁγίου Πνεύματος. Ἀμήν.",
    PrayerKey.SymbolumApostolorum to
        "Πιστεύω εἰς ἕνα Θεόν, Πατέρα, Παντοκράτορα, ποιητὴν οὐρανοῦ καὶ γῆς, ὁρατῶν τε πάντων καὶ ἀοράτων.\n" +
            "Καὶ εἰς ἕνα Κύριον Ἰησοῦν Χριστόν, τὸν Υἱὸν τοῦ Θεοῦ τὸν μονογενῆ, τὸν ἐκ τοῦ Πατρὸς γεννηθέντα πρὸ πάντων τῶν αἰώνων·\n" +
            "φῶς ἐκ φωτός, Θεὸν ἀληθινὸν ἐκ Θεοῦ ἀληθινοῦ, γεννηθέντα οὐ ποιηθέντα, ὁμοούσιον τῷ Πατρί, δι᾽ οὗ τὰ πάντα ἐγένετο.\n" +
            "Τὸν δι᾽ ἡμᾶς τοὺς ἀνθρώπους καὶ διὰ τὴν ἡμετέραν σωτηρίαν κατελθόντα ἐκ τῶν οὐρανῶν καὶ σαρκωθέντα ἐκ Πνεύματος Ἁγίου καὶ Μαρίας τῆς Παρθένου καὶ ἐνανθρωπήσαντα.\n" +
            "Σταυρωθέντα τε ὑπὲρ ἡμῶν ἐπὶ Ποντίου Πιλάτου, καὶ παθόντα καὶ ταφέντα.\n" +
            "Καὶ ἀναστάντα τῇ τρίτῃ ἡμέρᾳ κατὰ τὰς Γραφάς.\n" +
            "Καὶ ἀνελθόντα εἰς τοὺς οὐρανοὺς καὶ καθεζόμενον ἐκ δεξιῶν τοῦ Πατρός.\n" +
            "Καὶ πάλιν ἐρχόμενον μετὰ δόξης κρῖναι ζῶντας καὶ νεκρούς, οὗ τῆς βασιλείας οὐκ ἔσται τέλος.\n" +
            "Καὶ εἰς τὸ Πνεῦμα τὸ Ἅγιον, τὸ Κύριον, τὸ ζωοποιόν, τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον, τὸ σὺν Πατρὶ καὶ Υἱῷ συμπροσκυνούμενον καὶ συνδοξαζόμενον, τὸ λαλῆσαν διὰ τῶν προφητῶν.\n" +
            "Εἰς μίαν, Ἁγίαν, Καθολικὴν καὶ Ἀποστολικὴν Ἐκκλησίαν.\n" +
            "Ὁμολογῶ ἓν βάπτισμα εἰς ἄφεσιν ἁμαρτιῶν.\n" +
            "Προσδοκῶ ἀνάστασιν νεκρῶν καὶ ζωὴν τοῦ μέλλοντος αἰῶνος. Ἀμήν.",
    PrayerKey.PaterNoster to
        "Πάτερ ἡμῶν ὁ ἐν τοῖς οὐρανοῖς, ἁγιασθήτω τὸ ὄνομά σου·\n" +
        "ἐλθέτω ἡ βασιλεία σου· γενηθήτω τὸ θέλημά σου,\n" +
        "ὡς ἐν οὐρανῷ καὶ ἐπὶ τῆς γῆς.\n" +
        "Τὸν ἄρτον ἡμῶν τὸν ἐπιούσιον δὸς ἡμῖν σήμερον·\n" +
        "καὶ ἄφες ἡμῖν τὰ ὀφειλήματα ἡμῶν,\n" +
        "ὡς καὶ ἡμεῖς ἀφίεμεν τοῖς ὀφειλέταις ἡμῶν·\n" +
        "καὶ μὴ εἰσενέγκῃς ἡμᾶς εἰς πειρασμόν,\n" +
        "ἀλλὰ ῥῦσαι ἡμᾶς ἀπὸ τοῦ πονηροῦ. Ἀμήν.",
    PrayerKey.AveMaria to
        "Θεοτόκε Παρθένε, χαῖρε,\n" +
        "κεχαριτωμένη Μαρία, ὁ Κύριος μετὰ σοῦ.\n" +
        "Εὐλογημένη σὺ ἐν γυναιξί,\n" +
        "καὶ εὐλογημένος ὁ καρπὸς τῆς κοιλίας σου, ὅτι Σωτῆρα ἔτεκες τῶν ψυχῶν ἡμῶν.\n" +
        "Ἁγία Μαρία, Μήτηρ τοῦ Θεοῦ,\n" +
        "πρέσβευε ὑπὲρ ἡμῶν τῶν ἁμαρτωλῶν,\n" +
        "νῦν καὶ ἐν τῇ ὥρᾳ τοῦ θανάτου ἡμῶν. Ἀμήν.",
    PrayerKey.GloriaPatri to
        "Δόξα Πατρὶ καὶ Υἱῷ καὶ Ἁγίῳ Πνεύματι,\n" +
        "καὶ νῦν καὶ ἀεὶ\n" +
        "καὶ εἰς τοὺς αἰῶνας τῶν αἰώνων. Ἀμήν.",
    PrayerKey.DoxologiaMinor to
        "Ὅτι σοῦ ἐστιν ἡ βασιλεία καὶ ἡ δύναμις καὶ ἡ δόξα εἰς τοὺς αἰῶνας. Ἀμήν.",
    PrayerKey.SubTuumPraesidiumTitle to
        "Ὑπὸ τὴν σὴν εὐσπλαγχνίαν",
    PrayerKey.SubTuumPraesidium to
        "Ὑπὸ τὴν σὴν εὐσπλαγχνίαν καταφεύγομεν,\n" +
        "Θεοτόκε·\n" +
        "τὰς ἡμῶν ἱκεσίας μὴ παρίδῃς ἐν περιστάσει,\n" +
        "ἀλλ᾽ ἐκ κινδύνων λύτρωσαι ἡμᾶς,\n" +
        "μόνη ἁγνή, μόνη εὐλογημένη.",
    PrayerKey.VersiculumStandard to
        "Πρέσβευε ὑπὲρ ἡμῶν, ἁγία Θεοτόκε.",
    PrayerKey.ResponsiumStandard to
        "Ὅπως ἄξιοι γενώμεθα τῶν ἐπαγγελιῶν τοῦ Χριστοῦ.",
    PrayerKey.VersiculumPaschale to
        "Χαῖρε καὶ ἀγάλλου, Παρθένε Μαρία, ἀλληλούϊα.",
    PrayerKey.ResponsiumPaschale to
        "Ὅτι ὄντως ἀνέστη ὁ Κύριος, ἀλληλούϊα.",
    PrayerKey.AveMariaProFide to
        "Χαῖρε Μαρία — εἰς αὔξησιν τῆς πίστεως.",
    PrayerKey.AveMariaProSpe to
        "Χαῖρε Μαρία — εἰς αὔξησιν τῆς ἐλπίδος.",
    PrayerKey.AveMariaProCaritate to
        "Χαῖρε Μαρία — εἰς αὔξησιν τῆς ἀγάπης.",
    PrayerKey.DecadeOrdinalFormat to
        "{noun} {n}",
    PrayerKey.RepetitionCounterConnector to
        "ἐκ",
    PrayerKey.FructusMysteriiLabel to
        "Καρπὸς τοῦ Μυστηρίου",
    PrayerKey.OratioIesu to
        "Κύριε Ἰησοῦ Χριστέ, Υἱὲ τοῦ Θεοῦ, ἐλέησόν με τὸν ἁμαρτωλόν.",
)
