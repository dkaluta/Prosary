namespace Prosary.Models;

/// <summary>
/// The fixed catalog of all fourteen Stations of the Cross, in order. This is static structural
/// data (which station is 3rd, etc.), not business logic — display text lives in the content
/// layer, keyed by each station's <see cref="Station.ImageKey"/>. The Stations equivalent of
/// <see cref="MysteryCatalog"/>.
/// </summary>
public static class StationsCatalog
{
    public static readonly IReadOnlyList<Station> All =
    [
        new Station(1, "station_01_condemned_to_death"),
        new Station(2, "station_02_carries_his_cross"),
        new Station(3, "station_03_falls_first_time"),
        new Station(4, "station_04_meets_his_mother"),
        new Station(5, "station_05_simon_of_cyrene"),
        new Station(6, "station_06_veronica"),
        new Station(7, "station_07_falls_second_time"),
        new Station(8, "station_08_women_of_jerusalem"),
        new Station(9, "station_09_falls_third_time"),
        new Station(10, "station_10_stripped_of_garments"),
        new Station(11, "station_11_nailed_to_the_cross"),
        new Station(12, "station_12_dies_on_the_cross"),
        new Station(13, "station_13_taken_down_from_the_cross"),
        new Station(14, "station_14_laid_in_the_tomb"),
    ];
}
