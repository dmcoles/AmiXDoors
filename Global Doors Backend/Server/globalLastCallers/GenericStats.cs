﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace GlobalLastCallers
{
    public class GenericStats
    {
        public List<GenericStat> stats { get; set; }
        public List<string> bbs{ get; set; }
        public int dayCount { get; set; }
        public int currentDay { get; set; }
        public string endDate { get; set; }

        public GenericStats()
        {
            stats = new List<GenericStat>();
            bbs = new List<string>();
        }

        public void Add(string name, Int64 value)
        {
            GenericStat g = new GenericStat() { name = name, count = value };
            stats.Add(g);
        }
    }

    public class GenericStat
    {
        public string name { get; set; }
        public Int64 count { get; set; }
    }
}