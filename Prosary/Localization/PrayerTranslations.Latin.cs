namespace Prosary.Localization;

public static partial class PrayerTranslations
{
    private static readonly Dictionary<string, string> Latin = new()
    {
        [PrayerKey.SignumCrucis] =
            "In nomine Patris, et Filii, et Spiritus Sancti. Amen.",

        [PrayerKey.SymbolumApostolorum] =
            "Credo in Deum Patrem omnipotentem, Creatorem caeli et terrae. Et in Iesum Christum, Filium " +
            "eius unicum, Dominum nostrum, qui conceptus est de Spiritu Sancto, natus ex Maria Virgine, " +
            "passus sub Pontio Pilato, crucifixus, mortuus, et sepultus, descendit ad inferos, tertia die " +
            "resurrexit a mortuis, ascendit ad caelos, sedet ad dexteram Dei Patris omnipotentis, inde " +
            "venturus est iudicare vivos et mortuos. Credo in Spiritum Sanctum, sanctam Ecclesiam " +
            "catholicam, sanctorum communionem, remissionem peccatorum, carnis resurrectionem, et vitam " +
            "aeternam. Amen.",

        [PrayerKey.PaterNoster] =
            "Pater noster, qui es in caelis, sanctificetur nomen tuum. Adveniat regnum tuum. Fiat voluntas " +
            "tua, sicut in caelo et in terra.\nPanem nostrum cotidianum da nobis hodie, et dimitte nobis " +
            "debita nostra, sicut et nos dimittimus debitoribus nostris. Et ne nos inducas in tentationem, " +
            "sed libera nos a malo. Amen.",

        [PrayerKey.AveMaria] =
            "Ave Maria, gratia plena, Dominus tecum. Benedicta tu in mulieribus, et benedictus fructus " +
            "ventris tui, Iesus.\nSancta Maria, Mater Dei, ora pro nobis peccatoribus, nunc et in hora " +
            "mortis nostrae. Amen.",

        [PrayerKey.GloriaPatri] =
            "Gloria Patri, et Filio, et Spiritui Sancto.\nSicut erat in principio, et nunc, et semper, et " +
            "in saecula saeculorum. Amen.",

        [PrayerKey.OratioFatimae] =
            "Domine Iesu, dimitte nobis debita nostra, libera nos ab igne inferni, conduc in caelum omnes " +
            "animas, praesertim illas quae maxime indigent misericordia tua.",

        [PrayerKey.RequiemAeternam] =
            "Requiem aeternam dona eis, Domine, et lux perpetua luceat eis. Requiescant in pace. Amen.",

        [PrayerKey.SanctusMichael] =
            "Sancte Michael Archangele, defende nos in proelio; contra nequitiam et insidias diaboli esto " +
            "praesidium. Imperet illi Deus, supplices deprecamur: tuque, Princeps militiae caelestis, " +
            "Satanam aliosque spiritus malignos, qui ad perditionem animarum pervagantur in mundo, divina " +
            "virtute in infernum detrude. Amen.",

        [PrayerKey.SalveRegina] =
            "Salve, Regina, mater misericordiae, vita, dulcedo, et spes nostra, salve. Ad te clamamus, " +
            "exsules filii Evae. Ad te suspiramus, gementes et flentes in hac lacrimarum valle. Eia ergo, " +
            "advocata nostra, illos tuos misericordes oculos ad nos converte. Et Iesum, benedictum fructum " +
            "ventris tui, nobis post hoc exsilium ostende. O clemens, O pia, O dulcis Virgo Maria.",

        [PrayerKey.AlmaRedemptorisMater] =
            "Alma Redemptoris Mater, quae pervia caeli porta manes, et stella maris, succurre cadenti " +
            "surgere qui curat populo; tu quae genuisti, natura mirante, tuum sanctum Genitorem, Virgo " +
            "prius ac posterius, Gabrielis ab ore sumens illud Ave, peccatorum miserere.",

        [PrayerKey.AveReginaCaelorum] =
            "Ave, Regina caelorum, Ave, Domina Angelorum: Salve, radix, salve, porta, Ex qua mundo lux est " +
            "orta: Gaude, Virgo gloriosa, Super omnes speciosa, Vale, o valde decora, Et pro nobis Christum " +
            "exora.",

        [PrayerKey.ReginaCaeli] =
            "Regina caeli, laetare, alleluia. Quia quem meruisti portare, alleluia. Resurrexit, sicut " +
            "dixit, alleluia. Ora pro nobis Deum, alleluia.",

        [PrayerKey.SubTuumPraesidium] =
            "Sub tuum praesidium confugimus, sancta Dei Genetrix; nostras deprecationes ne despicias in " +
            "necessitatibus nostris, sed a periculis cunctis libera nos semper, Virgo gloriosa et benedicta.",

        [PrayerKey.VersiculumStandard] = "Ora pro nobis, sancta Dei Genetrix.",
        [PrayerKey.ResponsiumStandard] = "Ut digni efficiamur promissionibus Christi.",
        [PrayerKey.CollectaStandard] =
            "Oremus. Deus, cuius Unigenitus per vitam, mortem, et resurrectionem suam nobis salutis " +
            "aeternae praemia comparavit: concede, quaesumus, ut haec mysteria sacratissimo beatae Mariae " +
            "Virginis Rosario recolentes, et imitemur quod continent, et quod promittunt assequamur. Per " +
            "eundem Christum Dominum nostrum. Amen.",

        [PrayerKey.VersiculumPaschale] = "Gaude et laetare, Virgo Maria, alleluia.",
        [PrayerKey.ResponsiumPaschale] = "Quia surrexit Dominus vere, alleluia.",
        [PrayerKey.CollectaPaschale] =
            "Oremus. Deus, qui per resurrectionem Filii tui, Domini nostri Iesu Christi, mundum " +
            "laetificare dignatus es: praesta, quaesumus, ut per eius Genetricem Virginem Mariam, " +
            "perpetuae capiamus gaudia vitae. Per eundem Christum Dominum nostrum. Amen.",

        [PrayerKey.AveMariaProFide] = "Ave Maria — ad augendam fidem.",
        [PrayerKey.AveMariaProSpe] = "Ave Maria — ad augendam spem.",
        [PrayerKey.AveMariaProCaritate] = "Ave Maria — ad augendam caritatem.",

        [PrayerKey.FructusMysteriiLabel] = "Fructus Mysterii",

        [PrayerKey.VersiculumAngelusPrimus] = "Angelus Domini nuntiavit Mariae.",
        [PrayerKey.ResponsiumAngelusPrimus] = "Et concepit de Spiritu Sancto.",
        [PrayerKey.VersiculumAngelusSecundus] = "Ecce ancilla Domini.",
        [PrayerKey.ResponsiumAngelusSecundus] = "Fiat mihi secundum verbum tuum.",
        [PrayerKey.VersiculumAngelusTertius] = "Et Verbum caro factum est.",
        [PrayerKey.ResponsiumAngelusTertius] = "Et habitavit in nobis.",
        [PrayerKey.CollectaAngelus] =
            "Oremus. Gratiam tuam, quaesumus, Domine, mentibus nostris infunde; ut qui, Angelo " +
            "nuntiante, Christi Filii tui incarnationem cognovimus, per passionem eius et crucem, ad " +
            "resurrectionis gloriam perducamur. Per eundem Christum Dominum nostrum. Amen.",

        [PrayerKey.OratioIesu] = "Domine Iesu Christe, Fili Dei, miserere mei peccatoris.",
    };
}
