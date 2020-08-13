using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace GlobalLastCallers
{
    public class DayStats
    {
        public string statdate { get; set; }
        public int calls { get; set; }
        public int topcps { get; set; }
        public Int64 uploads { get; set; }
        public Int64 downloads { get; set; }
    }
}