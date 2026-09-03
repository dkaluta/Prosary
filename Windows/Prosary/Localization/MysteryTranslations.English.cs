namespace Prosary.Localization;

// Descriptions are the Douay-Rheims Bible (1899 Challoner edition, public domain), quoted exactly.
public static partial class MysteryTranslations
{
    private static readonly Dictionary<string, MysteryText> English = new()
    {
        // Joyful
        ["joyful_01_annunciation"] = new(
            "The Annunciation", "Humility",
            "And in the sixth month, the angel Gabriel was sent from God into a city of Galilee, called " +
            "Nazareth, To a virgin espoused to a man whose name was Joseph, of the house of David; and the " +
            "virgin's name was Mary. And the angel being come in, said unto her: Hail, full of grace, the " +
            "Lord is with thee: blessed art thou among women. Who having heard, was troubled at his saying, " +
            "and thought with herself what manner of salutation this should be. And the angel said to her: " +
            "Fear not, Mary, for thou hast found grace with God. Behold thou shalt conceive in thy womb, and " +
            "shalt bring forth a son; and thou shalt call his name Jesus. He shall be great, and shall be " +
            "called the Son of the most High; and the Lord God shall give unto him the throne of David his " +
            "father; and he shall reign in the house of Jacob for ever. And of his kingdom there shall be no " +
            "end. And Mary said to the angel: How shall this be done, because I know not man? And the angel " +
            "answering, said to her: The Holy Ghost shall come upon thee, and the power of the most High " +
            "shall overshadow thee. And therefore also the Holy which shall be born of thee shall be called " +
            "the Son of God. And behold thy cousin Elizabeth, she also hath conceived a son in her old age; " +
            "and this is the sixth month with her that is called barren: Because no word shall be impossible " +
            "with God. And Mary said: Behold the handmaid of the Lord; be it done to me according to thy " +
            "word. And the angel departed from her.\n\n— Luke 1:26–38 (Douay-Rheims)"),
        ["joyful_02_visitation"] = new(
            "The Visitation", "Love of Neighbor",
            "And Mary rising up in those days, went into the hill country with haste into a city of Juda. " +
            "And she entered into the house of Zachary, and saluted Elizabeth. And it came to pass, that " +
            "when Elizabeth heard the salutation of Mary, the infant leaped in her womb. And Elizabeth was " +
            "filled with the Holy Ghost: And she cried out with a loud voice, and said: Blessed art thou " +
            "among women, and blessed is the fruit of thy womb. And whence is this to me, that the mother of " +
            "my Lord should come to me? For behold as soon as the voice of thy salutation sounded in my " +
            "ears, the infant in my womb leaped for joy. And blessed art thou that hast believed, because " +
            "those things shall be accomplished that were spoken to thee by the Lord.\n\n— Luke 1:39–45 (Douay-Rheims)"),
        ["joyful_03_nativity"] = new(
            "The Nativity", "Poverty of Spirit",
            "And it came to pass, that when they were there, her days were accomplished, that she should be " +
            "delivered. And she brought forth her firstborn son, and wrapped him up in swaddling clothes, " +
            "and laid him in a manger; because there was no room for them in the inn.\n\n— Luke 2:6–7 (Douay-Rheims)"),
        ["joyful_04_presentation"] = new(
            "The Presentation", "Obedience",
            "And after the days of her purification, according to the law of Moses, were accomplished, they " +
            "carried him to Jerusalem, to present him to the Lord: As it is written in the law of the Lord: " +
            "Every male opening the womb shall be called holy to the Lord: And to offer a sacrifice, " +
            "according as it is written in the law of the Lord, a pair of turtledoves, or two young " +
            "pigeons.\n\n— Luke 2:22–24 (Douay-Rheims)"),
        ["joyful_05_finding_in_the_temple"] = new(
            "The Finding in the Temple", "Piety",
            "And it came to pass, that, after three days, they found him in the temple, sitting in the " +
            "midst of the doctors, hearing them, and asking them questions. And all that heard him were " +
            "astonished at his wisdom and his answers. And seeing him, they wondered. And his mother said to " +
            "him: Son, why hast thou done so to us? behold thy father and I have sought thee sorrowing. And " +
            "he said to them: How is it that you sought me? did you not know, that I must be about my " +
            "father's business?\n\n— Luke 2:46–49 (Douay-Rheims)"),

        // Sorrowful
        ["sorrowful_01_agony_in_the_garden"] = new(
            "The Agony in the Garden", "Sorrow for Sin",
            "And he was withdrawn away from them a stone's cast; and kneeling down, he prayed, Saying: " +
            "Father, if thou wilt, remove this chalice from me: but yet not my will, but thine be done. And " +
            "there appeared to him an angel from heaven, strengthening him. And being in an agony, he prayed " +
            "the longer. And his sweat became as drops of blood, trickling down upon the ground.\n\n— Luke 22:41–44 (Douay-Rheims)"),
        ["sorrowful_02_scourging_at_the_pillar"] = new(
            "The Scourging at the Pillar", "Purity",
            "Then therefore, Pilate took Jesus, and scourged him.\n\n— John 19:1 (Douay-Rheims)"),
        ["sorrowful_03_crowning_with_thorns"] = new(
            "The Crowning with Thorns", "Moral Courage",
            "And the soldiers platting a crown of thorns, put it upon his head; and they put on him a " +
            "purple garment. And they came to him, and said: Hail, king of the Jews; and they gave him " +
            "blows.\n\n— John 19:2–3 (Douay-Rheims)"),
        ["sorrowful_04_carrying_of_the_cross"] = new(
            "The Carrying of the Cross", "Patience",
            "And bearing his own cross, he went forth to that place which is called Calvary, but in Hebrew " +
            "Golgotha.\n\n— John 19:17 (Douay-Rheims)"),
        ["sorrowful_05_crucifixion"] = new(
            "The Crucifixion", "Salvation",
            "And it was almost the sixth hour; and there was darkness over all the earth until the ninth " +
            "hour. And the sun was darkened, and the veil of the temple was rent in the midst. And Jesus " +
            "crying out with a loud voice, said: Father, into thy hands I commend my spirit. And saying " +
            "this, he gave up the ghost.\n\n— Luke 23:44–46 (Douay-Rheims)"),

        // Glorious
        ["glorious_01_resurrection"] = new(
            "The Resurrection", "Faith",
            "And the angel answering, said to the women: Fear not you; for I know that you seek Jesus who " +
            "was crucified. He is not here, for he is risen, as he said. Come, and see the place where the " +
            "Lord was laid.\n\n— Matthew 28:5–6 (Douay-Rheims)"),
        ["glorious_02_ascension"] = new(
            "The Ascension", "Hope",
            "And when he had said these things, while they looked on, he was raised up: and a cloud received " +
            "him out of their sight. And while they were beholding him going up to heaven, behold two men " +
            "stood by them in white garments. Who also said: Ye men of Galilee, why stand you looking up to " +
            "heaven? This Jesus who is taken up from you into heaven, shall so come, as you have seen him " +
            "going into heaven.\n\n— Acts 1:9–11 (Douay-Rheims)"),
        ["glorious_03_descent_of_the_holy_spirit"] = new(
            "The Descent of the Holy Spirit", "Wisdom and Love of God",
            "And suddenly there came a sound from heaven, as of a mighty wind coming, and it filled the " +
            "whole house where they were sitting. And there appeared to them parted tongues as it were of " +
            "fire, and it sat upon every one of them: And they were all filled with the Holy Ghost, and they " +
            "began to speak with divers tongues, according as the Holy Ghost gave them to speak.\n\n— Acts 2:2–4 (Douay-Rheims)"),
        ["glorious_04_assumption"] = new(
            "The Assumption of Mary", "Grace of a Happy Death",
            "And a great sign appeared in heaven: A woman clothed with the sun, and the moon under her " +
            "feet, and on her head a crown of twelve stars.\n\n— Apocalypse 12:1 (Douay-Rheims)"),
        ["glorious_05_coronation"] = new(
            "The Coronation of Mary", "Trust in Mary's Intercession",
            "And a great sign appeared in heaven: A woman clothed with the sun, and the moon under her " +
            "feet, and on her head a crown of twelve stars.\n\n— Apocalypse 12:1 (Douay-Rheims)"),

        // Luminous
        ["luminous_01_baptism"] = new(
            "The Baptism in the Jordan", "Openness to the Holy Spirit",
            "And Jesus being baptized, forthwith came out of the water: and lo, the heavens were opened to " +
            "him: and he saw the Spirit of God descending as a dove, and coming upon him. And behold a voice " +
            "from heaven, saying: This is my beloved Son, in whom I am well pleased.\n\n— Matthew 3:16–17 (Douay-Rheims)"),
        ["luminous_02_wedding_at_cana"] = new(
            "The Wedding at Cana", "To Jesus through Mary",
            "Jesus saith to them: Fill the waterpots with water. And they filled them up to the brim. And " +
            "Jesus saith to them: Draw out now, and carry to the chief steward of the feast. And they " +
            "carried it. And when the chief steward had tasted the water made wine, and knew not whence it " +
            "was, but the waiters knew who had drawn the water; the chief steward calleth the bridegroom, " +
            "And saith to him: Every man at first setteth forth good wine, and when men have well drunk, " +
            "then that which is worse. But thou hast kept the good wine until now. This beginning of " +
            "miracles did Jesus in Cana of Galilee; and manifested his glory, and his disciples believed in " +
            "him.\n\n— John 2:7–11 (Douay-Rheims)"),
        ["luminous_03_proclamation_of_the_kingdom"] = new(
            "The Proclamation of the Kingdom", "Repentance and Trust in God",
            "And after that John was delivered up, Jesus came into Galilee, preaching the gospel of the " +
            "kingdom of God, And saying: The time is accomplished, and the kingdom of God is at hand: " +
            "repent, and believe the gospel.\n\n— Mark 1:14–15 (Douay-Rheims)"),
        ["luminous_04_transfiguration"] = new(
            "The Transfiguration", "Desire for Holiness",
            "And after six days Jesus taketh unto him Peter and James, and John his brother, and bringeth " +
            "them up into a high mountain apart: And he was transfigured before them. And his face did " +
            "shine as the sun: and his garments became white as snow. ... And as he was yet speaking, " +
            "behold a bright cloud overshadowed them. And lo, a voice out of the cloud, saying: This is my " +
            "beloved Son, in whom I am well pleased: hear ye him.\n\n— Matthew 17:1–2, 5 (Douay-Rheims)"),
        ["luminous_05_institution_of_the_eucharist"] = new(
            "The Institution of the Eucharist", "Adoration and Love of the Eucharist",
            "And whilst they were at supper, Jesus took bread, and blessed, and broke: and gave to his " +
            "disciples, and said: Take ye, and eat. This is my body. And taking the chalice, he gave thanks: " +
            "and gave to them, saying: Drink ye all of this. For this is my blood of the new testament, " +
            "which shall be shed for many unto remission of sins.\n\n— Matthew 26:26–28 (Douay-Rheims)"),

    };
}
