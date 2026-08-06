//
//  PrayerTranslations+Greek.swift
//  Prosary
//
//  Liturgical Greek, polytonic. Deliberately partial: the keys below are prayers whose *original*
//  language is Greek (the Creed as the Council wrote it, the Sub Tuum on Rylands Papyrus 470, the
//  Jesus Prayer, the doxology) or plain UI labels. The Latin-tradition prayers — Salve Regina,
//  Alma Redemptoris Mater, Ave Regina Caelorum, Regina Caeli, the Fatima Prayer, the St. Michael
//  prayer, Eternal Rest, Anima Christi, both collects — are absent on purpose: Greek renderings
//  exist in Greek Catholic use, but not ones this app can cite, and `PrayerTranslations.get`
//  falls back to Latin per key. Adding an invented translation of a prayer a community actually
//  recites is worse than the honest Latin fallback. See Shared/ARCHITECTURE.md.
//
//  Scripture in Greek follows the Septuagint (Rahlfs) for the Old Testament and the Patriarchal
//  Text of 1904 for the New — one tradition end to end, both public domain, and what is read
//  aloud in Greek churches. Bundle content follows the same sources.
//

import Foundation

extension PrayerTranslations {
  static let greek: [PrayerKey: String] = [
    .signumCrucis:
      "Εἰς τὸ ὄνομα τοῦ Πατρὸς καὶ τοῦ Υἱοῦ καὶ τοῦ Ἁγίου Πνεύματος. Ἀμήν.",

    // Greek use says the Nicene-Constantinopolitan Creed wherever the Latin tradition says the
    // Apostles' — including the Rosary's opening — so it takes that key outright here, exactly as
    // the Mission of St. Gamaliel's rite does. This is the conciliar Greek, not a translation.
    .symbolumApostolorum:
      "Πιστεύω εἰς ἕνα Θεόν, Πατέρα, Παντοκράτορα, ποιητὴν οὐρανοῦ καὶ γῆς, ὁρατῶν τε πάντων " +
      "καὶ ἀοράτων.\n" +
      "Καὶ εἰς ἕνα Κύριον Ἰησοῦν Χριστόν, τὸν Υἱὸν τοῦ Θεοῦ τὸν μονογενῆ, τὸν ἐκ τοῦ Πατρὸς " +
      "γεννηθέντα πρὸ πάντων τῶν αἰώνων·\n" +
      "φῶς ἐκ φωτός, Θεὸν ἀληθινὸν ἐκ Θεοῦ ἀληθινοῦ, γεννηθέντα οὐ ποιηθέντα, ὁμοούσιον τῷ " +
      "Πατρί, δι᾽ οὗ τὰ πάντα ἐγένετο.\n" +
      "Τὸν δι᾽ ἡμᾶς τοὺς ἀνθρώπους καὶ διὰ τὴν ἡμετέραν σωτηρίαν κατελθόντα ἐκ τῶν οὐρανῶν καὶ " +
      "σαρκωθέντα ἐκ Πνεύματος Ἁγίου καὶ Μαρίας τῆς Παρθένου καὶ ἐνανθρωπήσαντα.\n" +
      "Σταυρωθέντα τε ὑπὲρ ἡμῶν ἐπὶ Ποντίου Πιλάτου, καὶ παθόντα καὶ ταφέντα.\n" +
      "Καὶ ἀναστάντα τῇ τρίτῃ ἡμέρᾳ κατὰ τὰς Γραφάς.\n" +
      "Καὶ ἀνελθόντα εἰς τοὺς οὐρανοὺς καὶ καθεζόμενον ἐκ δεξιῶν τοῦ Πατρός.\n" +
      "Καὶ πάλιν ἐρχόμενον μετὰ δόξης κρῖναι ζῶντας καὶ νεκρούς, οὗ τῆς βασιλείας οὐκ ἔσται " +
      "τέλος.\n" +
      "Καὶ εἰς τὸ Πνεῦμα τὸ Ἅγιον, τὸ Κύριον, τὸ ζωοποιόν, τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον, τὸ " +
      "σὺν Πατρὶ καὶ Υἱῷ συμπροσκυνούμενον καὶ συνδοξαζόμενον, τὸ λαλῆσαν διὰ τῶν προφητῶν.\n" +
      "Εἰς μίαν, Ἁγίαν, Καθολικὴν καὶ Ἀποστολικὴν Ἐκκλησίαν.\n" +
      "Ὁμολογῶ ἓν βάπτισμα εἰς ἄφεσιν ἁμαρτιῶν.\n" +
      "Προσδοκῶ ἀνάστασιν νεκρῶν καὶ ζωὴν τοῦ μέλλοντος αἰῶνος. Ἀμήν.",

    // Matthew 6:9-13, Patriarchal Text — the prayer as it was first written down.
    .paterNoster:
      "Πάτερ ἡμῶν ὁ ἐν τοῖς οὐρανοῖς, ἁγιασθήτω τὸ ὄνομά σου·\n" +
      "ἐλθέτω ἡ βασιλεία σου· γενηθήτω τὸ θέλημά σου, ὡς ἐν οὐρανῷ καὶ ἐπὶ τῆς γῆς.\n" +
      "Τὸν ἄρτον ἡμῶν τὸν ἐπιούσιον δὸς ἡμῖν σήμερον·\n" +
      "καὶ ἄφες ἡμῖν τὰ ὀφειλήματα ἡμῶν, ὡς καὶ ἡμεῖς ἀφίεμεν τοῖς ὀφειλέταις ἡμῶν·\n" +
      "καὶ μὴ εἰσενέγκῃς ἡμᾶς εἰς πειρασμόν, ἀλλὰ ῥῦσαι ἡμᾶς ἀπὸ τοῦ πονηροῦ. Ἀμήν.",

    // Two halves from two traditions, joined the way Greek Catholics pray the Rosary: the
    // salutation is the Byzantine hymn "Θεοτόκε Παρθένε" (itself Luke 1:28,42 with the Church's
    // own closing line), the petition the Latin Rosary's. Worth a native reviewer's eye.
    .aveMaria:
      "Θεοτόκε Παρθένε, χαῖρε, κεχαριτωμένη Μαρία, ὁ Κύριος μετὰ σοῦ.\n" +
      "Εὐλογημένη σὺ ἐν γυναιξί, καὶ εὐλογημένος ὁ καρπὸς τῆς κοιλίας σου, ὅτι Σωτῆρα ἔτεκες " +
      "τῶν ψυχῶν ἡμῶν.\n" +
      "Ἁγία Μαρία, Μήτηρ τοῦ Θεοῦ, πρέσβευε ὑπὲρ ἡμῶν τῶν ἁμαρτωλῶν, νῦν καὶ ἐν τῇ ὥρᾳ τοῦ " +
      "θανάτου ἡμῶν. Ἀμήν.",

    .gloriaPatri:
      "Δόξα Πατρὶ καὶ Υἱῷ καὶ Ἁγίῳ Πνεύματι,\n" +
      "καὶ νῦν καὶ ἀεὶ καὶ εἰς τοὺς αἰῶνας τῶν αἰώνων. Ἀμήν.",

    // The Matthean doxology, in the Greek the Divine Liturgy sings after the Our Father.
    .doxologiaMinor:
      "Ὅτι σοῦ ἐστιν ἡ βασιλεία καὶ ἡ δύναμις καὶ ἡ δόξα εἰς τοὺς αἰῶνας. Ἀμήν.",

    .subTuumPraesidiumTitle: "Ὑπὸ τὴν σὴν εὐσπλαγχνίαν",

    // The oldest known Marian prayer, and Greek is its own language — this is the Rylands
    // Papyrus 470 text as the Church has continued to pray it, not a translation of the Latin.
    .subTuumPraesidium:
      "Ὑπὸ τὴν σὴν εὐσπλαγχνίαν καταφεύγομεν, Θεοτόκε·\n" +
      "τὰς ἡμῶν ἱκεσίας μὴ παρίδῃς ἐν περιστάσει,\n" +
      "ἀλλ᾽ ἐκ κινδύνων λύτρωσαι ἡμᾶς,\n" +
      "μόνη ἁγνή, μόνη εὐλογημένη.",

    .versiculumStandard: "Πρέσβευε ὑπὲρ ἡμῶν, ἁγία Θεοτόκε.",
    .responsiumStandard: "Ὅπως ἄξιοι γενώμεθα τῶν ἐπαγγελιῶν τοῦ Χριστοῦ.",

    .versiculumPaschale: "Χαῖρε καὶ ἀγάλλου, Παρθένε Μαρία, ἀλληλούϊα.",
    .responsiumPaschale: "Ὅτι ὄντως ἀνέστη ὁ Κύριος, ἀλληλούϊα.",

    .aveMariaProFide: "Χαῖρε Μαρία — εἰς αὔξησιν τῆς πίστεως.",
    .aveMariaProSpe: "Χαῖρε Μαρία — εἰς αὔξησιν τῆς ἐλπίδος.",
    .aveMariaProCaritate: "Χαῖρε Μαρία — εἰς αὔξησιν τῆς ἀγάπης.",

    .decadeOrdinalFormat: "{noun} {n}",

    .repetitionCounterConnector: "ἐκ",

    .fructusMysteriiLabel: "Καρπὸς τοῦ Μυστηρίου",

    // Greek is this prayer's own language too.
    .oratioIesu: "Κύριε Ἰησοῦ Χριστέ, Υἱὲ τοῦ Θεοῦ, ἐλέησόν με τὸν ἁμαρτωλόν.",
  ]
}
