﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace GlobalLastCallers
{
    public class CallerDetails
    {
        public int Id { get; set; }
        public string Username { get; set; }
        public string Location { get; set; }
        public string Bbsname { get; set; }
        public string Dateon { get; set; }
        public string Timeon { get; set; }
        public string Timeoff { get; set; }
        public string Actions { get; set; }
        public int? Upload { get; set; }
        public int? Download { get; set; }
        public int? TopCps { get; set; }
        public List<int> ConfNums { get; set; }
        public List<int> ConfUploads { get; set; }
        public List<string> UploadFiles { get; set; }
        public List<string> DownloadFiles { get; set; }
        public bool? Stealth { get; set; }

    }
}