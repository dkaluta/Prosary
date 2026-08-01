// PrayerPackStore (and its installed-packs directory) is process-global static state, and
// several test classes install/remove packs through it — running test collections in parallel
// let PrayerPackLoaderTests mutate the store mid-iteration of CustomDevotionEngineTests'
// every-bundle sweeps ("Collection was modified"). The suite is fast; serialize it.
[assembly: Xunit.CollectionBehavior(DisableTestParallelization = true)]
