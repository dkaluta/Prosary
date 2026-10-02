# 1 Maccabees OCR baseline — chapter 1

Research draft; not a certified transcription or import source.

Compared PDF B97–105 with the exact Kahana Wikisource chapter (revision 1288876) and the visually typed print draft.

PDF SHA-256: `656891d377d2e3d4a9216723d94205488423907bf01df424b9f0b9de1560051e`. Online HTML SHA-256: `3a3d3881d1b4fe55e1ea05c011eb8465707ffaf2acf058935ef4c442a5430047`.

The comparison uses the shared minimum-word-edit aligner and removes pointing and punctuation only. It preserves spelling, prefixes, suffixes, final letters and non-Hebrew OCR noise. Repeated-word alignments remain candidates.

Online words: 689; OCR words: 636; exactly aligned consonantal words: 329; unresolved OCR difference blocks: 193.

The visual draft has 59 printed units covering labels 1–64. Its 85 differences from Wikisource are retained for adjudication; the draft is not an independent accuracy benchmark.

## Page evidence

| PDF page | OCR engine confidence | OCR text SHA-256 |
| --- | ---: | --- |
| 97 | 31 | `c8c660b06412f6c59bd028a993073f6aba6f294df4365bda8e56be0021a98ef6` |
| 98 | 37 | `35ee273de0251ac2f6a89ba34817567d0c0d768bb7765c95981ddb778eceed45` |
| 99 | 37 | `36d1edf6885c965a5f29e2c3563ae3a1d9648870d08e98d5660d6c1b7b6b5bd5` |
| 100 | 33 | `8546102af6b0d0a778a9dd66c7811d2d71a55e653ccf742890861585b047f580` |
| 101 | 35 | `9da5199dbdae4ad15937d46baaa371998b31375bb6d5df543c4a777e26d39247` |
| 102 | 35 | `527c2ced4b4f5468ad8a95b143e76951778ad843509ebd80671c55370178711b` |
| 103 | 34 | `e587c7fa9eb155fa2255ba7034ca23652272dc399c1570578b1ad0d5f494adf4` |
| 104 | 34 | `0f8e400905889d7931d39847bb00b06ef5e6ff3c3061f7729ea2c32d10d951bc` |
| 105 | 35 | `90e3f1bfb3524ed77f931363726af0966b4bbe3289628ae8f4d8f5fd019f7fc3` |

## Printed labels and unresolved mixed layout

These OCR boxes touch the visually located label margin and are excluded from Scripture alignment. Their raw words and coordinates remain in the JSON evidence. A mixed box may include both a label and body letters; it requires manual review rather than an automatic split.

| PDF page | OCR text | Classification |
| --- | --- | --- |
| 97 | א | printed_margin |
| 97 | כ | printed_margin |
| 97 | \| | printed_margin |
| 97 | ג | printed_margin |
| 97 | \| | printed_margin |
| 98 | ר | printed_margin |
| 98 | \| | mixed_margin_body_unresolved |
| 98 | ה | printed_margin |
| 98 | = | mixed_margin_body_unresolved |
| 98 | ו | printed_margin |
| 98 | \| | printed_margin |
| 98 | ו | printed_margin |
| 98 | \| | printed_margin |
| 98 | ח-ט | printed_margin |
| 99 | י, | printed_margin |
| 100 | יא | printed_margin |
| 100 | \| | printed_margin |
| 100 | יב | printed_margin |
| 100 | \| | printed_margin |
| 100 | יג | printed_margin |
| 100 | \| | printed_margin |
| 100 | יר-מוקעשות | mixed_margin_body_unresolved |
| 101 | . | printed_margin |
| 101 | ו | printed_margin |
| 101 | \| | printed_margin |
| 101 | יח | printed_margin |
| 101 | \| | printed_margin |
| 101 | ים | printed_margin |
| 101 | \| | printed_margin |
| 101 | כ | printed_margin |
| 101 | \| | printed_margin |
| 101 | נא | printed_margin |
| 102 | כנ | printed_margin |
| 102 | \| | mixed_margin_body_unresolved |
| 102 | ג | printed_margin |
| 102 | \| | printed_margin |
| 102 | כד | printed_margin |
| 102 | \| | mixed_margin_body_unresolved |
| 102 | כה | printed_margin |
| 102 | \| | mixed_margin_body_unresolved |
| 102 | כו | printed_margin |
| 102 | מ | printed_margin |
| 102 | כח | printed_margin |
| 102 | \| | printed_margin |
| 103 | כט | printed_margin |
| 103 | ל | printed_margin |
| 103 | \| | printed_margin |
| 103 | לא | printed_margin |
| 103 | לכ | printed_margin |
| 103 | \| | printed_margin |
| 103 | לג | printed_margin |
| 103 | \| | printed_margin |
| 103 | לד | printed_margin |
| 103 | לה | printed_margin |
| 103 | לו | printed_margin |
| 103 | \| | printed_margin |
| 103 | לו | printed_margin |
| 103 | \| | printed_margin |
| 103 | לח | printed_margin |
| 103 | = | printed_margin |
| 103 | לט | printed_margin |
| 103 | \| | printed_margin |
| 103 | ם | printed_margin |
| 103 | \| | printed_margin |
| 103 | מא-מנ | mixed_margin_body_unresolved |
| 103 | מג | printed_margin |
| 103 | \| | printed_margin |
| 104 | מו | printed_margin |
| 104 | \| | mixed_margin_body_unresolved |
| 104 | מה | printed_margin |
| 104 | \| | printed_margin |
| 104 | מו | printed_margin |
| 104 | - | printed_margin |
| 104 | מז | mixed_margin_body_unresolved |
| 104 | מה | printed_margin |
| 104 | \| | printed_margin |
| 104 | סש | printed_margin |
| 104 | נ-גא | mixed_margin_body_unresolved |
| 104 | נכ | printed_margin |
| 104 | \| | printed_margin |
| 104 | ג | printed_margin |
| 104 | \| | printed_margin |
| 104 | : | printed_margin |
| 104 | נה | printed_margin |
| 104 | \| | mixed_margin_body_unresolved |
| 105 | = | printed_margin |
| 105 | מ | printed_margin |
| 105 | \| | printed_margin |
| 105 | נה | printed_margin |
| 105 | \| | printed_margin |
| 105 | ₪ | printed_margin |
| 105 | \| | printed_margin |
| 105 | ם | printed_margin |
| 105 | \| | printed_margin |
| 105 | כא | printed_margin |
| 105 | סג | printed_margin |
| 105 | סג | printed_margin |
| 105 | סר | printed_margin |
| 105 | \| | printed_margin |

## Source-unit alignment

| Printed label | Located PDF pages | Aligned OCR pages | Matched words | Both endpoints matched | Unexpected pages |
| --- | --- | --- | ---: | --- | --- |
| 1 | [97] | [97] | 9/25 | False | [] |
| 2 | [97] | [97] | 3/8 | False | [] |
| 3 | [97, 98] | [97, 98] | 5/14 | False | [] |
| 4 | [98] | [98] | 6/12 | False | [] |
| 5 | [98] | [98] | 3/9 | False | [] |
| 6 | [98] | [98] | 4/13 | False | [] |
| 7 | [98] | [98] | 3/6 | False | [] |
| 8–9 | [98] | [98] | 12/18 | False | [] |
| 10 | [99, 100] | [99, 100] | 10/21 | False | [] |
| 11 | [100] | [100] | 18/26 | True | [] |
| 12 | [100] | [100] | 1/3 | False | [] |
| 13 | [100] | [] | 0/12 | False | [] |
| 14–15 | [100, 101] | [100, 101] | 7/16 | True | [] |
| 16 | [101] | [101] | 6/13 | True | [] |
| 17 | [101] | [101] | 4/9 | False | [] |
| 18 | [101] | [101] | 8/13 | False | [] |
| 19 | [101] | [101] | 7/9 | False | [] |
| 20 | [101] | [101] | 9/17 | False | [] |
| 21 | [101, 102] | [102] | 2/14 | False | [] |
| 22 | [102] | [102] | 11/22 | False | [] |
| 23 | [102] | [102] | 9/14 | False | [] |
| 24 | [102] | [102] | 6/10 | True | [] |
| 25 | [102] | [102] | 4/6 | False | [] |
| 26 | [102] | [102] | 4/9 | False | [] |
| 27 | [102] | [102] | 3/7 | False | [] |
| 28 | [102] | [102] | 1/9 | False | [] |
| 29 | [103] | [103] | 7/14 | True | [] |
| 30 | [103] | [103] | 12/19 | False | [] |
| 31 | [103] | [103] | 7/12 | False | [] |
| 32 | [103] | [103] | 2/8 | False | [] |
| 33 | [103] | [103] | 7/12 | False | [] |
| 34 | [103] | [103] | 2/8 | False | [] |
| 35 | [103] | [103] | 7/11 | False | [] |
| 36 | [103] | [103] | 2/8 | False | [] |
| 37 | [103] | [103] | 3/8 | False | [] |
| 38 | [103] | [103] | 6/12 | False | [] |
| 39 | [103] | [103] | 3/11 | False | [] |
| 40 | [103] | [103] | 1/7 | False | [] |
| 41–42 | [103] | [103] | 5/19 | False | [] |
| 43 | [103, 104] | [103, 104] | 7/9 | True | [] |
| 44 | [104] | [104] | 6/13 | False | [] |
| 45 | [104] | [104] | 2/9 | False | [] |
| 46–47 | [104] | [104] | 9/11 | False | [] |
| 48 | [104] | [104] | 8/11 | False | [] |
| 49 | [104] | [104] | 2/6 | False | [] |
| 50–51 | [104] | [104] | 11/22 | False | [] |
| 52 | [104] | [104] | 4/12 | False | [] |
| 53 | [104] | [] | 0/6 | False | [] |
| 54 | [104] | [104] | 12/18 | False | [] |
| 55 | [104, 105] | [104, 105] | 3/4 | False | [] |
| 56 | [105] | [105] | 6/7 | False | [] |
| 57 | [105] | [105] | 8/14 | True | [] |
| 58 | [105] | [105] | 5/8 | True | [] |
| 59 | [105] | [105] | 4/10 | False | [] |
| 60 | [105] | [105] | 6/10 | False | [] |
| 61 | [105] | [105] | 5/11 | False | [] |
| 62 | [105] | [105] | 5/8 | False | [] |
| 63 | [105] | [105] | 5/10 | False | [] |
| 64 | [105] | [105] | 2/6 | False | [] |

## Unresolved OCR differences

All rows require source review; a difference is not permission to substitute the online wording.

| Reference label(s) | PDF page(s) | Wikisource words | Observed/draft words |
| --- | --- | --- | --- |
| [1] | [97] | ויהי אחרי הַכּוׂת | והי אמָרי הבות |
| [1] | [] | בן |  |
| [1] | [97] | פילפוס | בְּדְפִילפים |
| [1] | [] | אשר |  |
| [1] | [97] | יצא | אסֶרדוְצָא |
| [1] | [97] | כיתים | כַתִים |
| [1] | [97] | חיל | מיל |
| [1] | [] | ויך |  |
| [1] | [97] | את דריָוֶש מלך | ניך אֶתדרְרְנוֶש מָלֶ |
| [1] | [97] | ומדי וימלוך | וּמָרִי ימל |
| [1, 2] | [97] | יון ויערוך מלחמות רבות וילכוד | יָן מערר מִלְרָמות רות לפ |
| [2] | [97] | וישחט | נשמט |
| [3] | [97] | ויבוא עד | ניבא ער |
| [3] | [] | וייקח |  |
| [3] | [97] | שְלל גויים | גקח שלליגוּים |
| [3] | [98] | ותשקוט | נתשָקט |
| [3] | [98] | לפניו וירם ויגבה | לְפְגִיו ַיָרֶם נִיגְכָה |
| [4] | [98] | ויאסוף חיל | גיאֶסף מל |
| [4] | [98] | מאוד וימלוך | מָאד וַיְמְלך |
| [4] | [98] | ורוזנים ויהיו | וְרוּזִָים נַיְהְיוּ |
| [5] | [98] | ויהיה אחר | וַיְהִי אַמַר |
| [5] | [] | ויפול למשכב |  |
| [5] | [98] | וידע כי | ויפל קְמְְכְבנמדעבִי |
| [6] | [] | ויקרא לעבדיו |  |
| [6] | [98] | הנכבדים אשר גדלו | ניקְרָא לפְבְדָיו הִַכְבּריםאַטֶריגְרְלוּ |
| [6] | [98] | מנעוריו ויחלק להם | מְנֶשרִיו נְמַלק כָהֶם |
| [6] | [98] | בעודנו | בְּעידְנוּ |
| [7] | [98] | וימלוך אלכסנדר | מל אַלְכְסַוְרר |
| [7, 8] | [98] | וימות וישלטו | ניָמת נשקטו |
| [9] | [98] | וישימו כולם | נישימוּ כָלֶם |
| [9] | [98] | אחריהם | אַמְרִיהֶם |
| [9] | [98] | וירבו | נַיַרְבּוּ |
| [9, 10] | [98, 99] | בארץ ויצא | כְארֶץ נמצא |
| [10] | [99] | שורש | שרש |
| [10] | [] | אנטיוכוס |  |
| [10] | [99] | אפיפנס בן אנטיוכוס | אַנְִיוכום אַפִיסְנֶם בְּזדאַנְטִיוכום |
| [10] | [] | בן |  |
| [10] | [99] | תערובות | בְְדתַעַרוּבות |
| [10] | [99] | וימלוך | ימל |
| [10] | [99] | ושלושים | ושלשים |
| [10] | [100] | היוונים | הַיוָנִים |
| [11] | [100] | וידיחו | ווריחו |
| [11] | [100] | לאמור | לאמר |
| [11] | [] | את |  |
| [11] | [100] | הגויים | אֶתההַגוּיִם |
| [11] | [100] | סביבותינו | פְבִיבוּתִינו |
| [11] | [] | מן |  |
| [11] | [100] | היום | מִדהִיום |
| [11] | [100] | סרנו | פַרנוּ |
| [12] | [100] | וייטב הדבר | נַיִיטֶב הַרְכָר |
| [13] | [] | ויתנדבו אנשים מן |  |
| [13] | [100] | העם וילכו אל המלך וישליטם המלך לעשות כחוקי הגויים | נַיתְנדְבוּ אֶגֶשים מִוְדהָעֶם יכו אֶלההַמֶלֶך נישליסם הַמֶלֶר כְּחְקִי הגוים |
| [14, 15] | [100] | בירושלים כמשפטי הגויים ויעשו | בִּירוּשֶלֶם כְמשְָטי הַגוּיִם יעשי |
| [15] | [] | ויעזבו |  |
| [15] | [101] | ברית קודש | גיעָוְבוּ בְּריתהקדש |
| [15] | [101] | לגוים ויתמכרו | לגיים ַיְתְמִכְרוּ |
| [16] | [101] | אנטיוכוס ויתנשא למלוך | אַנְמִייכים וִתְנשא למֶלך |
| [16] | [] | למען |  |
| [16] | [101] | מלוך על שתי | קמע מלך עלישתִי |
| [17] | [101] | ויבוא | נַוֶבא |
| [17] | [101] | כבד ברכב | כְּכַר בְּרֶב |
| [17, 18] | [101] | ובאֳני גדול ויערוך | וּכְאָנִי דול מערך |
| [18] | [101] | מלך | מלד |
| [18] | [101] | ויסוג | ניסוג |
| [18] | [101] | וינוס ויפלו | וינם נִיְִּלו |
| [19] | [101] | וילכדו | נִַיִלְכְדו |
| [19] | [101] | וייקח | ניִקַח |
| [20] | [101] | וישוב אנטיוכוס אחרי | נַיֶשָב אַנְמִייכוס אַמָרי |
| [20] | [101] | ושלוש ויעל | ושֶלש געל |
| [20] | [101] | ועל ירושלים | ְעַל וְרוּשְלֶם |
| [20, 21] | [] | כבד ויבוא |  |
| [21] | [101, 102] | אל המקדש בגאווה וייקח את מזבח | כְּכַד נוָבא אֶליהַמְקְרֶש בְּאַוֶה ניִקח אֶתימִזְבַּח |
| [21] | [] | ואת |  |
| [21] | [102] | מנורת | וְאֶתהמְטורת |
| [21] | [] | ואת כל |  |
| [21] | [102] | כֵליה | ואֶתהבְלדכָּלֶיהַ |
| [22] | [102] | שולחן | שֶלְמַן |
| [22] | [] | ואת הקשוות |  |
| [22] | [102] | המזרקות ואת כפות | הַקָשות וְאֶתההַמזרְקות וְאֶתהכַּפות |
| [22] | [102] | הפרוכת | הַפֶרכֶת |
| [22] | [102] | עדי | עַרִי |
| [22] | [102] | לפני | לפְִי |
| [22, 23] | [102] | ויפצל הכול וייקח | וצל הַפל ניִקח |
| [23] | [] | כלי |  |
| [23] | [102] | החמדה וייקח | בְלִיההַחְמְרָה וקה |
| [23] | [102] | אוצרות | אצָרוּת |
| [24] | [102] | הכול | הפל |
| [24] | [102] | ויעש | נועש |
| [24] | [102] | וידבר בגאוּת | ניִדפר בְּנָאות |
| [25, 26] | [102] | בכל מקומותיהם ויאנחו | בְּכֶלדמְקומוּתִיהֶם ו ַיּאְנְחוּ |
| [26] | [102] | ובחורים אומללו ויופי | וכחוּרים אִמְלָלו ויפי |
| [26, 27] | [102] | שונה וכל | שְגֶה וְמְל |
| [27] | [102] | נשא קינה | גֶשָא קִיגָה |
| [27] | [102] | בחופה | בַּתְפֶה |
| [28] | [] | חלה על |  |
| [28] | [102] | יושביה וכל בית יעקב לבש בושת | הְָלֶה עַלייושְבְיהָ ְכְליבִּית וָעָקב לְכש בּשֶת |
| [29] | [103] | שנתיים | שְנְתַיִם |
| [29] | [] | שר |  |
| [29] | [103] | המוּסים לערי יהודה ויבוא ירושלימה | שרדהַמופים קְעֶרִי יְהוּרָה ויבא וְרוּשְליְמָה |
| [30] | [103] | וידבר | נַיְדכַר |
| [30] | [103] | דברי | דִכְרִי |
| [30] | [103] | ויאמינו | ניאָמִיו |
| [30] | [103] | ויפול | ויפל |
| [30] | [103] | פתאום ויך | פִתָאם ניֶך |
| [30] | [103] | ויאבד | ְַאַבָּר |
| [31] | [103] | ויקח | ניקַח |
| [31] | [103] | וישׂרפֻהָּ | ישרפה |
| [31] | [103] | ויהרוס | נוֶהרם |
| [31] | [] | ואת |  |
| [31] | [103] | חומותיה | וְאֶתהחמוּתֶיהָ |
| [32] | [] | הנשים ואת |  |
| [32, 33] | [103] | הטף ואת הבהמה בזזו ויבנו | הַגֶשים וְאֶתההַעָף וְאֶתהכַבְּהַמָה בְזָו נַיבָנוי |
| [33] | [] | עיר |  |
| [33] | [103] | דוד | עִירחדְוד |
| [33] | [103] | וחזקה ובמגדלים | נַחַזְקָה וּבְמְגְרְלִים |
| [34] | [] | וישכון |  |
| [34] | [103] | שם | נִשפְודשֶָם |
| [34] | [] | חוטא |  |
| [34] | [103] | אנשי אוֶן ויתבצרו | חטא אַנשראָוָן נַיִתְכַּצָרוּ |
| [35] | [103] | ויצברו | יִַצְבְּרוּ |
| [35] | [103] | ואוכל | וָאכְל |
| [35] | [] | שלל |  |
| [35] | [103] | ירושלים | שללחירושלם |
| [36] | [103] | ויהי למארב לבית המקדש ולשטן | ניָהִי קְמאָרֶב לְכִית הַמְקֶרֶש ּלְשָטֶן |
| [36, 37] | [103] | תמיד וישפכו | תָּמִיר נִַשְפְּכוי |
| [37] | [103] | מסביב למקדש ויטמאו | מִסָכִיב למִקֶרֶש וְַמְאוּ |
| [37, 38] | [103] | המקדש וינוסו | הַמְקֶרֶש ונופו |
| [38] | [103] | ירושלים בגללם ותהי | יְרוּשָלֶם בְּנְלְלֶם ַתְּהִי |
| [38] | [103] | ותהי | ַתְּהִי |
| [38] | [103] | ובניה | וְּניהָ |
| [39] | [] | בית |  |
| [39] | [103] | המקדש הוּשם כמדבר חגיה נהפכו | בִּיתההַמְקְדֶש הָשם כַמַרְבָר ַגִיהָ גְהְפְכוּ |
| [39] | [103] | לכלימה כבודה | לְבְּלְמָה מְבידָה |
| [40] | [103] | כרוב כבודה גדל קלונה וגודלה נהפך | כְּרב בְּכוּרֶה גֶרל קְלְגָה ֶדְלָה גְרֶפֶר |
| [41] | [103] | ויכתוב המלך | ויִמְתם הַמְלֶר |
| [41] | [] | כל |  |
| [41] | [103] | מלכותו | כֶלרמלְכותו |
| [41] | [103] | כולם | כְּלֶם |
| [41, 42] | [103] | אחד ולעזוב | אֶחָר לעוב |
| [42] | [] | את חוקותיו |  |
| [42] | [103] | ויקבלו כל העמים כדבר המלך | אֶתחתְקוּתָיו נַיְִבְּלו כְּלדהָעַמִים כַּרְבר הַמָּלֶר |
| [43] | [104] | ויזבחו | ניְכָחו |
| [43] | [104] | ויחללו | גְמַלְלוּ |
| [44] | [104] | וישלח המלך ספרים ביד | שלח הַמָלֶד מְפָרִים בֶּר |
| [44] | [104] | לירושלים | לירושָלֶם |
| [44] | [104] | חוקים נכרים | חְקִיס ְכְרים |
| [45] | [] | ולמנוע |  |
| [45] | [104] | עולות וזבח ונסך מן המקדש | לְמְנע עלות וכח סד מךהַמְקדש |
| [45, 46] | [104] | וחגים ולטמא | וְחָנִים וּלְסמא |
| [47, 48] | [104] | טמאות ולהניח | מָמַאוּת וְלְהַנִימַ |
| [48] | [104] | ולשקץ | וקשקָץ |
| [48, 49] | [104] | ופיגול לשכוח | ופְגול לשְפח |
| [49, 50] | [104] | ולהחליף כל החוקים ואשר | ולְהַמַלִיף בֶּל הַחְקִים גאֶשָר |
| [50] | [] | יעשה כדבר |  |
| [50] | [104] | המלך | יְעֶשָהכךְכריהַמָלֶך |
| [51] | [104] | ככול הדברים | פְּכֶל הַרְכְרִים |
| [51] | [104] | למלכותו ויפקד פקידים | קַמַלְכותו גפְקַד פֶקירים |
| [51] | [104] | כל | בֶל |
| [51] | [104] | ויצו | ויו |
| [52] | [104] | ויתחברו | נַיְתְמַבָּרו |
| [52] | [] | מן העם כל |  |
| [52] | [104] | עוזב את התורה ויעשו | מִדדהְָעְם כֶּלהעזב אֶתיהַתוּרֶה נעשוּ |
| [53] | [] | וישימו את |  |
| [53, 54] | [104] | ישראל במחבואים בכל מנוסם ובחמישה | ניֶשימו אֶתדיִשְרְאֶל בְּמְהַבואִים בְּכֶלימְגוֶם כחֶמשָה |
| [54] | [104] | בכסליו | בְּכַסְלו |
| [54] | [104] | שנה | קְגֶה |
| [54] | [104] | שיקוץ | שקוץ |
| [54] | [104] | המזבח | הַמְזְבֶה |
| [54] | [104] | מסביב | מִסָבִים |
| [55] | [105] | זבחו | וְכָהוּ |
| [56] | [105] | בקורעם | בְּקְרְעֶָם |
| [57] | [] | אשר |  |
| [57] | [105] | ימצא | אַשֶרדימְצא |
| [57] | [105] | ספר | ססר |
| [57] | [105] | יחפוץ | וחֶפץ |
| [57] | [105] | דת המלך | דֶתה הַמְלֶר |
| [58] | [105] | לנמצאים חודש בחודשו | למְצָאִים חרש בְּחְרשו |
| [59] | [105] | ובחמישה ועשרים לחודש | וכְחֶמשָה וְעֶטָרִים לחרש |
| [59] | [] | הייתה |  |
| [59] | [105] | על המזבח | הְיְתָה עְלרהַמַזְבָּםַ |
| [60] | [105] | הנשים | הַגֶשים |
| [60] | [] | על |  |
| [60, 61] | [105] | פי הפקודה ויתלו | עַליפי הַפְּקְרָה נַיִתְלוּ |
| [61] | [105] | העוללים בצוואריהם | הֶשלְלים בְּצַוְארִיהֶן |
| [61] | [] | בני |  |
| [61] | [105] | בתיהם | בְּנייבְתִיהֶן |
| [61] | [105] | המיתו | הַמית |
| [62] | [105] | ויתחזקו | ניתְמִזְקוּ |
| [62, 63] | [105] | אכול טמא ויבחרו | אָכל סְמא נִַבְחַרוּ |
| [63] | [] | חלל |  |
| [63, 64] | [105] | ברית קודש וימותו ויהיה | הלל בֶּריתדקרש נַימותו גַיָהִי |
| [64] | [] | על |  |
| [64] | [105] | ישראל מאוד | עלדישראל מאר |

## Wikisource versus visual draft

All rows require source review; a difference is not permission to substitute the online wording.

| Reference label(s) | PDF page(s) | Wikisource words | Observed/draft words |
| --- | --- | --- | --- |
| [1] | [97] | כיתים | כִּתִּים |
| [1] | [97] | וימלוך | וַיִּמְלֹךְ |
| [2] | [97] | ויערוך | וַיַּעֲרֹךְ |
| [2] | [97] | וילכוד | וַיִּלְכֹּד |
| [3] | [97, 98] | ויבוא | וַיָּבֹא |
| [3] | [97, 98] | וייקח | וַיִּקַּח |
| [3] | [97, 98] | גויים | גּוֹיִם |
| [3] | [97, 98] | ותשקוט | וַתִּשְׁקֹט |
| [4] | [98] | ויאסוף | וַיֶּאֱסֹף |
| [4] | [98] | מאוד וימלוך | מְאֹד וַיִּמְלֹךְ |
| [5] | [98] | ויהיה | וַיְהִי |
| [5] | [98] | ויפול | וַיִּפֹּל |
| [7] | [98] | וימלוך | וַיִּמְלֹךְ |
| [7] | [98] | וימות | וַיָּמֹת |
| [9] | [98] | כולם | כֻלָּם |
| [10] | [99, 100] | שורש | שֹׁרֶשׁ |
| [10] | [99, 100] | וימלוך | וַיִּמְלֹךְ |
| [10] | [99, 100] | ושלושים | וּשְׁלֹשִׁים |
| [10] | [99, 100] | היוונים | הַיְּוָנִים |
| [11] | [100] | לאמור | לֵאמֹר |
| [11] | [100] | הגויים | הַגּוֹיִם |
| [13] | [100] | כחוקי הגויים | כְּחֻקֵּי הַגּוֹיִם |
| [14] | [100, 101] | בירושלים | בִּירוּשָׁלִַם |
| [14] | [100, 101] | הגויים | הַגּוֹיִם |
| [15] | [100, 101] | קודש | קֹדֶשׁ |
| [16] | [101] | למלוך | לִמְלֹךְ |
| [16] | [101] | מלוך | מְלֹךְ |
| [17] | [101] | ויבוא | וַיָּבֹא |
| [18] | [101] | ויערוך | וַיַּעֲרֹךְ |
| [18] | [101] | וינוס | וַיָּנָס |
| [19] | [101] | וייקח | וַיִּקַּח |
| [20] | [101] | וישוב | וַיָּשָׁב |
| [20] | [101] | ושלוש | וְשָׁלֹשׁ |
| [20] | [101] | ירושלים | יְרוּשָׁלִַם |
| [21] | [101, 102] | ויבוא | וַיָּבֹא |
| [21] | [101, 102] | בגאווה וייקח | בְּגַאֲוָה וַיִּקַּח |
| [22] | [102] | שולחן | שֻׁלְחַן |
| [22] | [102] | הקשוות | הַקְּשָׂוֹת |
| [22] | [102] | הפרוכת | הַפָּרֹכֶת |
| [22, 23] | [102] | הכול וייקח | הַכֹּל וַיִּקַּח |
| [23] | [102] | וייקח | וַיִּקַּח |
| [24] | [102] | הכול | הַכֹּל |
| [26] | [102] | אומללו ויופי | אֻמְלָלוּ וְיֹפִי |
| [26] | [102] | שונה | שֻׁנָּה |
| [27] | [102] | בחופה | בְּחֻפָּה |
| [28] | [102] | בושת | בֹּשֶׁת |
| [29] | [103] | שנתיים | שְׁנָתַיִם |
| [29] | [103] | ויבוא | וַיָּבֹא |
| [30] | [103] | ויפול | וַיִּפֹּל |
| [30] | [103] | פתאום | פִּתְאֹם |
| [31] | [103] | ויהרוס | וַיַּהֲרֹס |
| [34] | [103] | וישכון | וַיִּשְׁכֹּן |
| [35] | [103] | ואוכל | וְאֹכֶל |
| [35] | [103] | ירושלים | יְרוּשָׁלִַם |
| [38] | [103] | ירושלים | יְרוּשָׁלִַם |
| [39] | [103] | הוּשם | הֻשַׁם |
| [39] | [103] | לכלימה | לִכְלִמָּה |
| [40] | [103] | כרוב | כְּרֹב |
| [40] | [103] | וגודלה | וְגָדְלָהּ |
| [41] | [103] | ויכתוב | וַיִּכְתֹּב |
| [41] | [103] | כולם | כֻּלָּם |
| [42] | [103] | ולעזוב | וְלַעֲזֹב |
| [42] | [103] | חוקותיו | חֻקּוֹתָיו |
| [44] | [104] | לירושלים | לִירוּשָׁלִַם |
| [44] | [104] | חוקים | חֻקִּים |
| [45] | [104] | ולמנוע עולות | וְלִמְנֹעַ עֹלוֹת |
| [48] | [104] | נפשותם | נַפְשׁוֹתֵיהֶם |
| [48, 49] | [104] | ופיגול לשכוח | וּפִגּוּל לִשְׁכֹּחַ |
| [49] | [104] | החוקים | הַחֻקִּים |
| [51] | [104] | ככול | כְּכָל |
| [54] | [104] | ובחמישה | וּבַחֲמִשָּׁה |
| [54] | [104] | בכסליו | בְּכִסְלֵו |
| [54] | [104] | שיקוץ | שִׁקּוּץ |
| [56] | [105] | בקורעם | בְּקָרְעָם |
| [57] | [105] | יחפוץ | יַחְפֹּץ |
| [58] | [105] | חודש בחודשו | חֹדֶשׁ בְּחָדְשׁוֹ |
| [59] | [105] | ובחמישה | וּבַחֲמִשָּׁה |
| [59] | [105] | לחודש | לַחֹדֶשׁ |
| [59] | [105] | הייתה | הָיְתָה |
| [60] | [105] | הפקודה | הַפְּקֻדָּה |
| [61] | [105] | בצוואריהם | בְּצַוְּארֵיהֶן |
| [61] | [105] | בתיהם | בֵיתֵיהֶן |
| [62] | [105] | אכול | אֲכֹל |
| [63, 64] | [105] | קודש וימותו ויהיה | קֹדֶשׁ וַיָּמֻתוּ וַיְהִי |
| [64] | [105] | מאוד | מְאֹד |

## Held-out vocabulary trial

Page B105 was recognized twice with the same image, model and settings. The optional dictionary contains 3712 distinct words from online chapters 2–16; all of chapter 1 is excluded. Its SHA-256 is `def26258576a1913a079b6e56e137919a0f81856668bc6388b56e56d7f0a641d`.

| Mode | Equal words | Replaced words | Missing words | Added words |
| --- | ---: | ---: | ---: | ---: |
| plain | 52 | 29 | 6 | 0 |
| vocabulary | 51 | 30 | 6 | 0 |

The reference is the visually typed draft and remains unreviewed. These are alignment counts, not an OCR accuracy measurement. Vocabulary also changes pointing, which this consonantal comparison cannot validate.


## Reproduction and limits

Run `Shared/tools/compare-1maccabees-ocr.py` with the pinned PDF, cached Wikisource HTML, source draft and `Shared/tools/ocr-1maccabees-page.cjs` as `--ocr-runner`. Set `PROSARY_HEBREW_OCR_RUNTIME` to the local directory containing Tesseract.js and `heb.traineddata`. Add `--vocabulary-trial` for the held-out page experiment. The output directory holds every page crop, OCR text, OCR metadata, and a full JSON alignment including context and unchanged uncertain words. `--evidence` writes compact durable evidence with all raw page OCR; `--markdown` writes this report.

Source draft SHA-256: `26b56dd0b6f3f0165ecb0f612a9201f7341e13a6e45e1a4d772af1d3de920734`. Neither the comparison nor the vocabulary trial changes that source draft.

- The manually typed pointed chapter is itself a draft; its differences require final print adjudication.
- Crops retain full Scripture lines and marginal labels. OCR word boxes in the known margin are recorded separately, not compared as Scripture. A merged body/margin box remains unresolved and is excluded without guessing its text.
- Exact consonantal agreement cannot verify niqqud, punctuation, word boundaries, or the correct occurrence of a repeated phrase.
- No differing OCR token is silently replaced from Wikisource. No page or book is marked reviewed by this tool.

## Print draft findings awaiting final review

- Initial Wikisource scaffold is not a complete pointed transcription. Every sourcePages-empty verse remains unreviewed and must not be imported.
- Wikisource response SHA-256: 3a3d3881d1b4fe55e1ea05c011eb8465707ffaf2acf058935ef4c442a5430047
- PDF97–98 first pointed transcription drafted; not yet marked reviewed: proper-name niqqud needs independent confirmation. Every verse remains subject to full final comparison.
- PDF98 prints combined margin label ח–ט. Source unit1:8–9 retained as one row. PDF100 also prints combined14–15; pending transcription.
- PDF99–102 first pointed transcription drafted, pending independent diacritic verification; no pages certified complete. Names are not mechanically vocalized.
- PDF100–101 prints combined14–15; PDF102 explicitly includes a three-dash bracketed lacuna at1:26, absent from the online scaffold.
- PDF103 first pointed transcription drafted through1:41–42. Source combines41–42. Full final diacritic verification remains outstanding, including doubtful vowel forms; no page marked complete.
- Chapter1 first pointed draft now spansPDF97–105,59 source units representing64 verse labels. None certified complete yet. Further combined units46–47 and50–51 preserved.
- PDF104-detail confirms defective ירושלם with the printed combined vowel marks; draft spelling corrected. Remaining targeted diacritic questions include כסלו1:54 and several worn vowel marks.
- B103 targeted print recheck at1:39 confirms defective הֻשַׁם, without ו; draft corrected. Chapter1 is explicitly partial because the printed1:26 lacuna is preserved. This does not certify chapter review.
- Unreviewed chapters2–16 scaffold reparsed with explicit HTML line-break separation; no source wording or pointing certified by that repair. The OCR baseline evidence freezes its original chapter1 reference snapshot.
- B105–107 initial pointed draft of2:1–14. Source combines4–5 and8–9. Preserve the printed bracketed2:13 lacuna and כְּ[בֵית־]אִישׁ at2:8–9. Every vowel and punctuation mark remains subject to final comparison; no page certified complete.
- Unresolved B107 marks: הרגו in2:8–9 and חפשיה in2:11 are deliberately left unpointed in this draft until their printed marks are resolved. Other worn marks and source-specific name pointing still need independent final comparison.
- B1082:15–28 compared consonant-by-consonant only; pointing has NOT been transcribed or certified for these rows. Corrected the online omission in2:19 (בקול גדול אם־כל־העמים אשר בבית־מלכות המלך שומעים לו), source אבותיו versus online אבותינו, source או versus online ואו at2:22, and source פינחס at2:26. Printed combined labels16–17 and20–21 preserved.
- B109–1102:29–69 compared for consonants and source unit boundaries only; printed niqqud remains to be transcribed. Source32 ends רבים without a verse-end sign;33 begins וישיגום. Retained source brackets [לעשות] at34, [ותחשב־לו] at51, [אדני] at54, and source name order חנניה עזריה מישאל at58–59. Added source-combined30–31,38–39,46–47,52–53,55–56,58–59,60–61,68–69.
- Printed verse-end signs in all scan-compared draft rows are encoded with Hebrew sof pasuq U+05C3, not ASCII colon. Untouched online-scaffold rows retain their provisional punctuation until scan comparison.
- Online scaffold reparsed for explicit empty inline-block column spacers as well as line breaks. This only repairs missing whitespace in unreviewed chapters; it does not infer or certify source words.
