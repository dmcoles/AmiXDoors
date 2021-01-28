﻿using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Web.Http.Description;

namespace GlobalLastCallers.Controller
{
    [RoutePrefix("api/GlobalLastCallers")]
    public class GlobalLastCallersController : ApiController
    {
        public enum StatType { weektopUploads, monthtopUploads, weektopBBSuploads, monthtopBBSuploads, weektopCallers, monthtopCallers, weektopBBSCalls, monthtopBBSCalls, weektopdownloads, monthtopdownloads, weektopBBSdownloads, monthtopBBSdownloads, }
        SqlConnection sqlConn = new SqlConnection(ConfigurationManager.ConnectionStrings["LastCallersDB"].ConnectionString + "; Connection Timeout = 60");

        private CallerDetails ReadItem(SqlDataReader sqlData)
        {
            CallerDetails detailItem = new CallerDetails();
            detailItem.Id = (int)sqlData["id"];
            detailItem.Username = (string)sqlData["username"];
            detailItem.Bbsname = (string)sqlData["bbsname"];
            detailItem.Dateon = (string)sqlData["dateon"];
            detailItem.Timeon = (string)sqlData["timeon"];
            detailItem.Timeoff = (string)sqlData["timeoff"];
            detailItem.Actions = (string)sqlData["actions"];

            if (sqlData.IsDBNull(sqlData.GetOrdinal("upload"))) detailItem.Upload = null; else detailItem.Upload = (int)sqlData["upload"];
            if (sqlData.IsDBNull(sqlData.GetOrdinal("download"))) detailItem.Download = null; else detailItem.Download = (int)sqlData["download"];

            return detailItem;
        }

        public IHttpActionResult GetCallerDetails(int id)
        {
            return Ok(new CallerDetails());
        }

        [Route("Stats")]
        public IHttpActionResult GetCallerStats([FromUri] StatType statType, [FromUri] int count = 10)
        {
            SqlCommand sqlCmd = null;
            GenericStats genericStat;
            List<GenericStats> statList = new List<GenericStats>();
            switch (statType)
            {
                case StatType.weektopUploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,upload)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) and upload > 0 group by username order by sum(convert(bigint, upload)) desc", sqlConn);
                        break;
                    }
                case StatType.monthtopUploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,upload)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) and upload > 0 group by username order by sum(convert(bigint, upload)) desc", sqlConn);
                        break;
                    }

                case StatType.weektopBBSuploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,upload)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) and upload > 0 group by bbsname order by sum(convert(bigint, upload)) desc", sqlConn);
                        break;
                    }

                case StatType.monthtopBBSuploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,upload)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) and upload > 0 group by bbsname order by sum(convert(bigint, upload)) desc", sqlConn);
                        break;
                    }

                case StatType.weektopCallers:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username, convert(bigint,count(*)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) group by username order by count(*) desc", sqlConn);
                        break;
                    }

                case StatType.monthtopCallers:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username, convert(bigint,count(*)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) group by username order by count(*) desc", sqlConn);
                        break;
                    }
                case StatType.weektopBBSCalls:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname, convert(bigint,count(*)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) group by bbsname order by count(*) desc", sqlConn);
                        break;
                    }

                case StatType.monthtopBBSCalls:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname, convert(bigint,count(*)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) group by bbsname order by count(*) desc", sqlConn);
                        break;
                    }
                case StatType.weektopdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,download)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) and download > 0 group by username order by sum(convert(bigint, download)) desc", sqlConn);
                        break;
                    }
                case StatType.monthtopdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,download)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) and download > 0 group by username order by sum(convert(bigint, download)) desc", sqlConn);
                        break;
                    }

                case StatType.weektopBBSdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,download)) from lastcallers where dateon >= (getdate() - (datepart(dw, getdate()) - 1)) and download > 0 group by bbsname order by sum(convert(bigint, download)) desc", sqlConn);
                        break;
                    }

                case StatType.monthtopBBSdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,download)) from lastcallers where dateon >= (getdate() - datepart(d, getdate() - 1)) and download > 0 group by bbsname order by sum(convert(bigint, download)) desc", sqlConn);
                        break;
                    }

            }
            if (sqlCmd != null)
            {
                if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
                SqlDataReader sqlData = sqlCmd.ExecuteReader();
                try
                {
                    while (sqlData.Read())
                    {
                        genericStat = new GenericStats();
                        genericStat.name = sqlData.GetString(0);
                        genericStat.count = sqlData.GetInt64(1);
                        statList.Add(genericStat);
                    }
                }
                finally
                {
                    sqlData.Close();
                    sqlData.Dispose();
                    sqlCmd.Dispose();
                }
            }

            return Ok(statList);
        }

        [HttpGet]
        [Route("")]
        // GET: api/GlobalLastCallers
        public IHttpActionResult GetLastCalls([FromUri] int count = 10, [FromUri] int start = 1, string tzname = null)
        {
            TimeZoneInfo tzi = null;
            int? tzMins = null;

            try
            {
                if (tzname != null) tzi = TimeZoneInfo.FindSystemTimeZoneById(tzname);
            }
            catch (TimeZoneNotFoundException)
            {
            }

            if (tzi != null) tzMins = (int)tzi.GetUtcOffset(DateTime.Now).TotalMinutes;

            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd;

            if (tzMins != null)
                sqlCmd = new SqlCommand("select * from " +
                "(select Top " + (start + count - 1).ToString() + " ROW_NUMBER() over(order by dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)) desc) as rn, " +
                "id, username, bbsname, " +
                "convert(varchar, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)), 105) as dateon, " +
                "substring(convert(char, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, convert(time, timeon)), 8), 1, 5) timeon, " +
                "case when timeoff='--:--' then timeoff else substring(convert(char, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, convert(time, timeoff)), 8), 1, 5) end timeoff, " +
                "actions, upload, download from LastCallers " +
                "order by dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)) desc,id desc) s where s.rn >= " + start.ToString(), sqlConn);
            else
                sqlCmd = new SqlCommand("select * from (select Top " + (start + count - 1).ToString() + " ROW_NUMBER() over(order by lastCallers.dateon desc,lastCallers.timeon desc) as rn,id,username,bbsname,convert(varchar,dateon,105) as dateon,timeon,timeoff,actions,upload,download from LastCallers order by lastCallers.dateon desc,lastCallers.timeon desc,id desc) s where s.rn>=" + start.ToString(), sqlConn);

            CallerStats stats = new CallerStats();

            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                while (sqlData.Read())
                {
                    stats.calls.Add(ReadItem(sqlData));
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }

            SqlCommand sqlCmd2 = new SqlCommand("select 1 as rid, convert(varchar,getdate() - 1,105) as statdate, count(*) as calls, isnull(sum(convert(bigint,upload)),0) as upload, isnull(sum(convert(bigint,download)),0) as download, isnull(max(topcps),0) as topcps from lastcallers where dateon = convert(date, getdate() - 1) union all select 2 as rid, convert(varchar,getdate() - 2,105) as statdate, count(*) as calls, isnull(sum(convert(bigint,upload)),0) as upload, isnull(sum(convert(bigint,download)),0) as download, isnull(max(topcps),0) as topcps from lastcallers where dateon = convert(date, getdate() - 2) order by rid", sqlConn);
            SqlDataReader sqlData2 = sqlCmd2.ExecuteReader();
            try
            {
                if (sqlData2.Read())
                {
                    stats.yesterdayStats.statdate = (string)sqlData2["statdate"];
                    stats.yesterdayStats.calls = (int)sqlData2["calls"];
                    stats.yesterdayStats.uploads = (Int64)sqlData2["upload"];
                    stats.yesterdayStats.downloads = (Int64)sqlData2["download"];
                    stats.yesterdayStats.topcps = (int)sqlData2["topcps"];
                }

                if (sqlData2.Read())
                {
                    stats.previousDayStats.statdate = (string)sqlData2["statdate"];
                    stats.previousDayStats.calls = (int)sqlData2["calls"];
                    stats.previousDayStats.uploads = (Int64)sqlData2["upload"];
                    stats.previousDayStats.downloads = (Int64)sqlData2["download"];
                    stats.previousDayStats.topcps = (int)sqlData2["topcps"];
                }
            }
            finally
            {
                sqlData2.Close();
                sqlData2.Dispose();
                sqlCmd2.Dispose();
            }

            SqlCommand sqlCmd3 = new SqlCommand("select count(*) as allcalls from lastCallers", sqlConn);
            try
            {
                stats.records.allcalls = (int)sqlCmd3.ExecuteScalar();
            }
            finally
            {
                sqlCmd3.Dispose();
            }


            SqlCommand sqlCmd4 = new SqlCommand("select top 3 bbsname,count(*) as subcount from lastCallers group by bbsname order by count(*) desc", sqlConn);
            SqlDataReader sqlData4 = sqlCmd4.ExecuteReader();
            try
            {
                if (sqlData4.Read())
                {
                    stats.records.calls = (int)sqlData4["subcount"];
                    stats.records.mostcalled = (string)sqlData4["bbsname"];
                }
                if (sqlData4.Read())
                {
                    stats.records.calls2 = (int)sqlData4["subcount"];
                    stats.records.secondmostcalled = (string)sqlData4["bbsname"];
                }
                if (sqlData4.Read())
                {
                    stats.records.calls3 = (int)sqlData4["subcount"];
                    stats.records.thirdmostcalled = (string)sqlData4["bbsname"];
                }
            }
            finally
            {
                sqlData4.Close();
                sqlData4.Dispose();
                sqlCmd4.Dispose();
            }

            SqlCommand sqlCmd5 = new SqlCommand("select top 1 count(*) as allcalls from lastCallers group by dateon order by allcalls desc", sqlConn);
            try
            {
                stats.records.recordcalls = (int)sqlCmd5.ExecuteScalar();
            }
            finally
            {
                sqlCmd5.Dispose();
            }

            return Ok(stats);
        }

        [HttpPost]
        // POST: api/GlobalLastCallers
        [ResponseType(typeof(CallerDetails))]
        public IHttpActionResult Post(CallerDetails newCaller, string tzname = null)
        {
            DateTime dateOn;
            CultureInfo provider = CultureInfo.InvariantCulture;
            object existingId;

            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            TimeZoneInfo tzi = null;
            int? tzMins = null;

            try
            {
                if (tzname != null) tzi = TimeZoneInfo.FindSystemTimeZoneById(tzname);
            }
            catch (TimeZoneNotFoundException)
            {
            }

            if (tzi != null) tzMins = (int)tzi.GetUtcOffset(DateTime.Now).TotalMinutes;


            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            dateOn = DateTime.ParseExact(newCaller.Dateon, "dd-MM-yy", provider);

            SqlCommand sqlCheckCmd = new SqlCommand("select min(id) from lastcallers where bbsname=@bbsname and username=@username and dateon=@dateon and timeon=@timeon and timeoff=@timeoff", sqlConn);
            sqlCheckCmd.Parameters.Add("username", SqlDbType.VarChar);
            sqlCheckCmd.Parameters.Add("bbsname", SqlDbType.VarChar);
            sqlCheckCmd.Parameters.Add("dateon", SqlDbType.Date);
            sqlCheckCmd.Parameters.Add("timeon", SqlDbType.VarChar);
            sqlCheckCmd.Parameters.Add("timeoff", SqlDbType.VarChar);
            sqlCheckCmd.Parameters["username"].Value = newCaller.Username;
            sqlCheckCmd.Parameters["bbsname"].Value = newCaller.Bbsname;
            sqlCheckCmd.Parameters["dateon"].Value = dateOn;
            sqlCheckCmd.Parameters["timeon"].Value = newCaller.Timeon;
            sqlCheckCmd.Parameters["timeoff"].Value = newCaller.Timeoff;
            sqlCheckCmd.CommandTimeout = 60;
            try
            {
                existingId = sqlCheckCmd.ExecuteScalar();
            }
            finally
            {
                sqlCheckCmd.Dispose();
            }

            if (existingId == DBNull.Value)
            {
                SqlCommand sqlCmd = new SqlCommand("insert into LastCallers (username,bbsname,dateon,timeon,timeoff,actions,upload,download,topcps,tzoffset) values (@username,@bbsname,@dateon,@timeon,@timeoff,@actions,@upload,@download,@topcps,@tzoffset) SELECT CAST(scope_identity() AS int);", sqlConn);
                sqlCmd.Parameters.Add("username", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("bbsname", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("dateon", SqlDbType.Date);
                sqlCmd.Parameters.Add("timeon", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("timeoff", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("actions", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("upload", SqlDbType.Int);
                sqlCmd.Parameters.Add("download", SqlDbType.Int);
                sqlCmd.Parameters.Add("topcps", SqlDbType.Int);
                sqlCmd.Parameters.Add("tzoffset", SqlDbType.Int);

                sqlCmd.Parameters["username"].Value = newCaller.Username;
                sqlCmd.Parameters["bbsname"].Value = newCaller.Bbsname;
                sqlCmd.Parameters["dateon"].Value = dateOn;
                sqlCmd.Parameters["timeon"].Value = newCaller.Timeon;
                sqlCmd.Parameters["timeoff"].Value = newCaller.Timeoff;
                sqlCmd.Parameters["actions"].Value = newCaller.Actions;
                sqlCmd.Parameters["upload"].Value = newCaller.Upload;
                sqlCmd.Parameters["download"].Value = newCaller.Download;
                sqlCmd.Parameters["topcps"].Value = newCaller.TopCps;
                if (tzMins != null)
                    sqlCmd.Parameters["tzoffset"].Value = tzMins;
                else
                    sqlCmd.Parameters["tzoffset"].Value = DBNull.Value;
                sqlCmd.CommandTimeout = 60;

                try
                {
                    newCaller.Id = (int)sqlCmd.ExecuteScalar();
                    newCaller.Dateon = dateOn.ToString("dd-MM-yy");
                }
                finally
                {
                    sqlCmd.Dispose();
                }
            }
            else
            {
                SqlCommand sqlUpdateCmd = new SqlCommand("update LastCallers set actions=@actions, upload=@upload, download=@download, topcps=@topcps, tzoffset=@tzoffset where id = @id", sqlConn);
                sqlUpdateCmd.Parameters.Add("actions", SqlDbType.VarChar);
                sqlUpdateCmd.Parameters.Add("upload", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("download", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("topcps", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("tzoffset", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("id", SqlDbType.Int);

                sqlUpdateCmd.Parameters["actions"].Value = newCaller.Actions;
                sqlUpdateCmd.Parameters["upload"].Value = newCaller.Upload;
                sqlUpdateCmd.Parameters["download"].Value = newCaller.Download;
                sqlUpdateCmd.Parameters["topcps"].Value = newCaller.TopCps;
                sqlUpdateCmd.Parameters["id"].Value = existingId;
                if (tzMins != null)
                    sqlUpdateCmd.Parameters["tzoffset"].Value = tzMins;
                else
                    sqlUpdateCmd.Parameters["tzoffset"].Value = DBNull.Value;
                sqlUpdateCmd.CommandTimeout = 60;

                try
                {
                    sqlUpdateCmd.ExecuteNonQuery();
                }
                finally
                {
                    sqlUpdateCmd.Dispose();
                }
                newCaller.Id = (int)existingId;
                newCaller.Dateon = dateOn.ToString("dd-MM-yy");
            }
            return Ok(newCaller);
        }


        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                sqlConn.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
