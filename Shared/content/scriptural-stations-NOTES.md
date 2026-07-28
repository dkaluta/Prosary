# Scriptural Stations of the Cross (St. John Paul II) — user-provided notes

User-supplied Hebrew titles + citations (2026-07-28) for a possible future generic devotion
bundle: the scriptural Way of the Cross Pope St. John Paul II introduced on Good Friday 1991.
IMPLEMENTED (2026-07-28) as the `scriptural` VARIANT of the stationsOfTheCross bundle (devotion.json variants[]), in la/en/he — kept for the record.

The traditional-stations Hebrew from the same notes (opening meditation + blessing, the
versicle/response, 14 titles with scriptural citations, closing prayer, Anima Christi, and the
concluding blessing) is already shipped in `stationsOfTheCross/content/he.json`.

## The fourteen scriptural stations (Hebrew titles + citations, as provided)

| # | Hebrew title | Citation |
|---|---|---|
| 1 | ישוע מתפלל בגת שמנים | Mk 14:32-36 |
| 2 | יהודה מוסר את ישוע למעצר | Mk 14:45-46 |
| 3 | ישוע נדון למות על ידי הסנהדרין | Mk 14:55, 60-64 |
| 4 | כיפא מתכחש לישוע | Mk 14:66-72 |
| 5 | משפט ישוע מול פילטוס | Mk 15:14-15 |
| 6 | ישוע מכתר בקוצים | Mk 15:17-19 |
| 7 | ישוע נושא את הצלב | Mk 15:20 |
| 8 | שמעון מקירניה נושא את הצלב עם ישוע | Mk 15:21 |
| 9 | ישוע פוגש את נשות ירושלים | Lk 23:27-28 |
| 10 | ישוע נצלב | Mk 15:24 |
| 11 | ישוע מבטיח את מלכותו לגנב הטוב | Lk 23:39-42 |
| 12 | ישוע מפקיד את מרים אמו לתלמיד האהוב עליו על הצלב | Jn 19:26-27 |
| 13 | ישוע מת על הצלב | Mk 15:33-39 |
| 14 | ישוע מנח בקבר | Lk 23:50-56 |

## Building it later

- New generic bundle (steps type), e.g. id `scripturalStations` — needs en/la content too
  (the 1991 station titles are published; meditations would be the cited passages from the
  Douay-Rheims/Vulgate/Delitzsch, same per-language sources as everything else).
- Artwork: ten scenes can reuse shipped imageKeys (1 → sorrowful_01_agony_in_the_garden,
  5 → station_01_condemned_to_death, 6 → sorrowful_03_crowning_with_thorns,
  7 → station_02_carries_his_cross, 8 → station_05_simon_of_cyrene,
  9 → station_08_women_of_jerusalem, 10 → station_11_nailed_to_the_cross,
  12 → seven_sorrows_05_crucifixion (ter Brugghen's Virgin-and-John crucifixion fits exactly),
  13 → station_12_dies_on_the_cross, 14 → station_14_laid_in_the_tomb). Four scenes need new
  Commons artwork: the kiss of Judas (Giotto's Scrovegni fresco is the obvious candidate),
  Christ before the Sanhedrin (e.g. Honthorst's *Christ before the High Priest*), the denial of
  Peter (e.g. Rembrandt's), and the good thief.
- The opening/closing prayers, versicle/response, and Anima Christi from the same notes are
  shared with the traditional stations and already live in `stationsOfTheCross/content/he.json`.
