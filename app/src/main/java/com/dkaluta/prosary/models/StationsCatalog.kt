package com.dkaluta.prosary.models

/** The fixed catalog of all fourteen Stations of the Cross, in order. This is static structural
 * data (which station is 3rd, etc.), not business logic — display text lives in the content
 * layer, keyed by each station's [Station.imageKey]. The Stations equivalent of MysteryCatalog. */
object StationsCatalog {
    val all: List<Station> = listOf(
        Station(order = 1, imageKey = "station_01_condemned_to_death"),
        Station(order = 2, imageKey = "station_02_carries_his_cross"),
        Station(order = 3, imageKey = "station_03_falls_first_time"),
        Station(order = 4, imageKey = "station_04_meets_his_mother"),
        Station(order = 5, imageKey = "station_05_simon_of_cyrene"),
        Station(order = 6, imageKey = "station_06_veronica"),
        Station(order = 7, imageKey = "station_07_falls_second_time"),
        Station(order = 8, imageKey = "station_08_women_of_jerusalem"),
        Station(order = 9, imageKey = "station_09_falls_third_time"),
        Station(order = 10, imageKey = "station_10_stripped_of_garments"),
        Station(order = 11, imageKey = "station_11_nailed_to_the_cross"),
        Station(order = 12, imageKey = "station_12_dies_on_the_cross"),
        Station(order = 13, imageKey = "station_13_taken_down_from_the_cross"),
        Station(order = 14, imageKey = "station_14_laid_in_the_tomb"),
    )
}
