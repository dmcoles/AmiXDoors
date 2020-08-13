using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace GlobalLastCallers
{
    public class CallerStats
    {
        public List<CallerDetails> calls { get; set; }
        public DayStats yesterdayStats { get; set; }
        public DayStats previousDayStats { get; set; }
        public TopStats records { get; set; }

        public CallerStats() {
            calls = new List<CallerDetails>();
            yesterdayStats = new DayStats();
            previousDayStats = new DayStats();
            records = new TopStats();
        }
    }
}