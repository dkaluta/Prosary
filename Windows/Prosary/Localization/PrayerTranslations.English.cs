namespace Prosary.Localization;

public static partial class PrayerTranslations
{
    private static readonly Dictionary<string, string> English = new()
    {
        [PrayerKey.SignumCrucis] =
            "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",

        [PrayerKey.SymbolumApostolorum] =
            "I believe in God, the Father almighty, Creator of heaven and earth, and in Jesus Christ, " +
            "His only Son, our Lord, who was conceived by the Holy Spirit, born of the Virgin Mary, " +
            "suffered under Pontius Pilate, was crucified, died and was buried; He descended into hell; " +
            "on the third day He rose again from the dead; He ascended into heaven, and is seated at the " +
            "right hand of God the Father almighty; from there He will come to judge the living and the " +
            "dead. I believe in the Holy Spirit, the holy catholic Church, the communion of saints, the " +
            "forgiveness of sins, the resurrection of the body, and life everlasting. Amen.",

        [PrayerKey.PaterNoster] =
            "Our Father, who art in heaven, hallowed be Thy name; Thy kingdom come; Thy will be done on " +
            "earth as it is in heaven.\nGive us this day our daily bread; and forgive us our trespasses as " +
            "we forgive those who trespass against us; and lead us not into temptation, but deliver us " +
            "from evil. Amen.",

        [PrayerKey.AveMaria] =
            "Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed " +
            "is the fruit of thy womb, Jesus.\nHoly Mary, Mother of God, pray for us sinners, now and at " +
            "the hour of our death. Amen.",

        [PrayerKey.GloriaPatri] =
            "Glory be to the Father, and to the Son, and to the Holy Spirit.\nAs it was in the beginning, " +
            "is now, and ever shall be, world without end. Amen.",

        [PrayerKey.OratioFatimae] =
            "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, " +
            "especially those who are in most need of Thy mercy.",

        [PrayerKey.RequiemAeternam] =
            "Eternal rest grant unto them, O Lord, and let perpetual light shine upon them. May they rest " +
            "in peace. Amen.",

        [PrayerKey.SanctusMichael] =
            "St. Michael the Archangel, defend us in battle. Be our protection against the wickedness and " +
            "snares of the devil. May God rebuke him, we humbly pray, and do thou, O Prince of the " +
            "heavenly host, by the power of God, thrust into hell Satan and all the evil spirits who " +
            "prowl about the world seeking the ruin of souls. Amen.",

        [PrayerKey.SalveRegina] =
            "Hail, holy Queen, Mother of Mercy, our life, our sweetness, and our hope. To thee do we cry, " +
            "poor banished children of Eve. To thee do we send up our sighs, mourning and weeping in this " +
            "valley of tears. Turn then, most gracious advocate, thine eyes of mercy toward us, and after " +
            "this our exile show unto us the blessed fruit of thy womb, Jesus. O clement, O loving, O " +
            "sweet Virgin Mary.",

        [PrayerKey.AlmaRedemptorisMater] =
            "Loving Mother of the Redeemer, gate of heaven, star of the sea, assist your people who have " +
            "fallen yet strive to rise again. To the wonderment of nature you bore your Creator, yet " +
            "remained a virgin after as before. You who received Gabriel's joyful greeting, have pity on " +
            "us poor sinners.",

        [PrayerKey.AveReginaCaelorum] =
            "Hail, O Queen of Heaven enthroned. Hail, by angels Mistress owned. Root of Jesse, Gate of " +
            "morn, whence the world's true light was born. Glorious Virgin, joy to thee, loveliest whom " +
            "in heaven they see. Fairest thou, where all are fair; plead with Christ our sins to spare.",

        [PrayerKey.ReginaCaeli] =
            "Queen of Heaven, rejoice, alleluia. For He whom you did merit to bear, alleluia, has risen as " +
            "He said, alleluia. Pray for us to God, alleluia.",

        [PrayerKey.SubTuumPraesidium] =
            "We fly to thy patronage, O holy Mother of God; despise not our petitions in our necessities, " +
            "but deliver us always from all dangers, O glorious and blessed Virgin.",

        [PrayerKey.VersiculumStandard] = "Pray for us, O holy Mother of God.",
        [PrayerKey.ResponsiumStandard] = "That we may be made worthy of the promises of Christ.",
        [PrayerKey.CollectaStandard] =
            "Let us pray. O God, whose only-begotten Son, by His life, death, and resurrection, has " +
            "purchased for us the rewards of eternal life; grant, we beseech Thee, that, meditating upon " +
            "these mysteries of the most holy Rosary of the Blessed Virgin Mary, we may imitate what they " +
            "contain and obtain what they promise, through the same Christ our Lord. Amen.",

        [PrayerKey.VersiculumPaschale] = "Rejoice and be glad, O Virgin Mary, alleluia.",
        [PrayerKey.ResponsiumPaschale] = "For the Lord has truly risen, alleluia.",
        [PrayerKey.CollectaPaschale] =
            "Let us pray. O God, who through the resurrection of Your Son, our Lord Jesus Christ, did " +
            "vouchsafe to give joy to the whole world; grant, we beseech You, that through the " +
            "intercession of the Virgin Mary, His Mother, we may lay hold of the joys of everlasting life, " +
            "through the same Christ our Lord. Amen.",

        [PrayerKey.AveMariaProFide] = "Hail Mary — for an increase of Faith.",
        [PrayerKey.AveMariaProSpe] = "Hail Mary — for an increase of Hope.",
        [PrayerKey.AveMariaProCaritate] = "Hail Mary — for an increase of Charity.",

        [PrayerKey.FructusMysteriiLabel] = "Fruit of the Mystery",

        [PrayerKey.VersiculumAngelusPrimus] = "The Angel of the Lord declared unto Mary.",
        [PrayerKey.ResponsiumAngelusPrimus] = "And she conceived of the Holy Spirit.",
        [PrayerKey.VersiculumAngelusSecundus] = "Behold the handmaid of the Lord.",
        [PrayerKey.ResponsiumAngelusSecundus] = "Be it done unto me according to Thy word.",
        [PrayerKey.VersiculumAngelusTertius] = "And the Word was made Flesh.",
        [PrayerKey.ResponsiumAngelusTertius] = "And dwelt among us.",
        [PrayerKey.CollectaAngelus] =
            "Let us pray. Pour forth, we beseech Thee, O Lord, Thy grace into our hearts; that we, to " +
            "whom the Incarnation of Christ Thy Son was made known by the message of an angel, may by " +
            "His Passion and Cross be brought to the glory of His Resurrection. Through the same Christ " +
            "our Lord. Amen.",

        [PrayerKey.OratioIesu] = "Lord Jesus Christ, Son of God, have mercy on me, a sinner.",

        [PrayerKey.StationsOpeningPrayer] =
            "My Lord Jesus Christ, You made this journey to die for me with unspeakable love, and I have " +
            "so many times unworthily abandoned You. But now I love You with all my heart, and, because " +
            "I love You, I am sincerely sorry for ever having offended You. Pardon me, my God, for the " +
            "sake of the merits of Your bitter Passion, and grant me the grace to accompany You in this " +
            "journey with true contrition for my sins, that I may attain to a happy eternity. Amen.",
        [PrayerKey.StationsVersicle] = "We adore You, O Christ, and we bless You.",
        [PrayerKey.StationsResponse] = "Because by Your holy Cross You have redeemed the world.",
        [PrayerKey.StationsClosingPrayer] =
            "Lord Jesus Christ, we thank You for the Passion by which You have redeemed us. Grant that, " +
            "having meditated on Your sufferings on earth, we may deserve to enjoy their fruit in " +
            "heaven, where You live and reign forever and ever. Amen.",

        [PrayerKey.SevenSorrowsVersicle] = "Pray for us, O most sorrowful Virgin.",
        [PrayerKey.SevenSorrowsResponse] = "That we may be made worthy of the promises of Christ.",
        [PrayerKey.SevenSorrowsCollect] =
            "Let us pray. O God, in whose Passion, according to the prophecy of Simeon, a sword of " +
            "sorrow pierced through the most sweet soul of the glorious Virgin Mary, His Mother: " +
            "mercifully grant that we, who devoutly call to mind her transfixion and sorrows, may, " +
            "through the glorious merits and prayers of all the Saints who stood faithfully beneath " +
            "the Cross, obtain the happy fruit of Thy Passion. Who livest and reignest, world without " +
            "end. Amen.",

        [PrayerKey.DivineMercyOffering] =
            "Eternal Father, I offer You the Body and Blood, Soul and Divinity of Your dearly beloved " +
            "Son, Our Lord Jesus Christ, in atonement for our sins and those of the whole world.",
        [PrayerKey.DivineMercyPetition] = "For the sake of His sorrowful Passion, have mercy on us and on the whole world.",
        [PrayerKey.DivineMercyClosingAcclamation] = "Holy God, Holy Mighty One, Holy Immortal One, have mercy on us and on the whole world.",
    };
}
