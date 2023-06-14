using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Web.Http;
using System.Web.Http.Description;

namespace GlobalLastCallers.Controller
{
    [RoutePrefix("api/GlobalLastCallers")]
    public class GlobalLastCallersController : ApiController
    {
        public enum StatType
        {
            weektopUploads, monthtopUploads, weektopBBSuploads, monthtopBBSuploads, weektopCallers, monthtopCallers, weektopBBSCalls, monthtopBBSCalls, weektopdownloads, monthtopdownloads, weektopBBSdownloads, monthtopBBSdownloads, weektopUserCps, monthtopUserCps, weektopBBSCps, monthtopBBSCps, weektopUploadsAmigaOnly, monthtopUploadsAmigaOnly,
            alltimeTopUploaders, alltimeTopBBSUploads, alltimeTopCallers, alltimeTopBBSCalls, alltimeTopDownloaders, alltimeTopBBSDownloads, alltimeTopUserCps, alltimeTopBBSCps, weektopBBSuploadsAmigaOnly, monthtopBBSuploadsAmigaOnly, weektopFileDownloads, monthtopFileDownloads, alltimeFileDownloads
        };

        SqlConnection sqlConn = new SqlConnection(ConfigurationManager.ConnectionStrings["LastCallersDB"].ConnectionString + "; Connection Timeout = 60");

        private CallerDetails ReadItem(SqlDataReader sqlData)
        {
            CallerDetails detailItem = new CallerDetails();
            detailItem.Id = (int)sqlData["id"];
            detailItem.Username = (string)sqlData["username"];
            if (sqlData.IsDBNull(sqlData.GetOrdinal("location"))) detailItem.Location = ""; else detailItem.Location = (string)sqlData["location"];
            detailItem.Bbsname = (string)sqlData["bbsname"];
            detailItem.Dateon = (string)sqlData["dateon"];
            detailItem.Timeon = (string)sqlData["timeon"];
            detailItem.Timeoff = (string)sqlData["timeoff"];
            detailItem.Actions = (string)sqlData["actions"];

            if (sqlData.IsDBNull(sqlData.GetOrdinal("upload"))) detailItem.Upload = null; else detailItem.Upload = (int)sqlData["upload"];
            if (sqlData.IsDBNull(sqlData.GetOrdinal("download"))) detailItem.Download = null; else detailItem.Download = (int)sqlData["download"];

            return detailItem;
        }

        private string getWeekDaysSql(int offset)
        {
            if (offset!=0)
                return "select 7,7,format(dateadd(wk,-"+offset.ToString()+",(getdate()-datepart(dw,getdate())+7)),'dd-MMM-yyyy')";
            else
                return "select datepart(dw,getdate()),7,format(getdate()-datepart(dw,getdate())+7,'dd-MMM-yyyy')";
        }

        private string getMonthDaysSql(int offset)
        {
            if (offset != 0)
                return "select datepart(d, eomonth(dateadd(m, -" + offset.ToString() + ", getdate()))),datepart(d, eomonth(dateadd(m, -" + offset.ToString() + ", getdate()))),format(eomonth(dateadd(m, -" + offset.ToString() + ", getdate())),'dd-MMM-yyyy')";
            else
                return "select datepart(d,getdate()),datepart(d,eomonth(getdate())),format(eomonth(getdate()),'dd-MMM-yyyy')";
        }

        public IHttpActionResult GetCallerDetails(int id)
        {
            return Ok(new CallerDetails());
        }

        [Route("Stats")]
        public IHttpActionResult GetCallerStats([FromUri] StatType statType, [FromUri] int count = 10, [FromUri] int offset = 0)
        {
            SqlCommand sqlCmd = null;
            SqlCommand sqlCmd2 = null;
            SqlCommand sqlCmd3 = null;

            GenericStats stats;
            stats = new GenericStats();
            switch (statType)
            {
                case StatType.weektopUploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, upload)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and upload > 0 group by username order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }
                case StatType.monthtopUploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, upload)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and upload > 0 group by username order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }

                case StatType.weektopBBSuploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,upload)) from lastcallers where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and stealth=0 and upload > 0 group by bbsname order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }

                case StatType.monthtopBBSuploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,upload)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and stealth=0 and upload > 0 group by bbsname order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }

                case StatType.weektopCallers:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username, convert(bigint,count(*)) from lastcallers where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 group by username order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                        break;
                    }

                case StatType.monthtopCallers:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username, convert(bigint,count(*)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 group by username order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }
                case StatType.weektopBBSCalls:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname, convert(bigint,count(*)) from lastcallers where stealth=0 and convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 group by bbsname order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }

                case StatType.monthtopBBSCalls:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname, convert(bigint,count(*)) from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 group by bbsname order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }
                case StatType.weektopdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,download)) from lastcallers where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and download > 0 group by username order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }
                case StatType.monthtopdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint,download)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and download > 0 group by username order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }

                case StatType.weektopBBSdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,download)) from lastcallers where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and stealth=0 and download > 0 group by bbsname order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }

                case StatType.monthtopBBSdownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint,download)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and stealth=0 and download > 0 group by bbsname order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }

                case StatType.weektopUserCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,max(convert(bigint,topcps)) from lastcallers where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and topcps > 0 group by username order by max(convert(bigint, topcps)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn); break;
                    }

                case StatType.monthtopUserCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,max(convert(bigint,topcps)) from lastcallers where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and topcps > 0 group by username order by max(convert(bigint, topcps)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }
                case StatType.weektopBBSCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,max(convert(bigint,topcps)) from lastcallers where stealth=0 and convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and topcps > 0 group by bbsname order by max(convert(bigint, topcps)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn);
                        break;
                    }

                case StatType.monthtopBBSCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,max(convert(bigint,topcps)) from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and topcps > 0 group by bbsname order by max(convert(bigint, topcps)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }

                case StatType.weektopUploadsAmigaOnly:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, confuploads.upload)) from lastcallers,confuploads,bbs where confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and confuploads.upload > 0 group by username order by sum(convert(bigint, confuploads.upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbs.bbsname from lastcallers,confuploads,bbs where stealth=0 and confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and confuploads.upload > 0", sqlConn);
                        break;
                    }
                case StatType.monthtopUploadsAmigaOnly:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, confuploads.upload)) from lastcallers,confuploads,bbs where confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and confuploads.upload > 0 group by username order by sum(convert(bigint, confuploads.upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbs.bbsname from lastcallers,confuploads,bbs where stealth=0 and confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and confuploads.upload > 0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopUploaders:
                    { 
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, upload)) from lastcallers group by username order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopBBSUploads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint, upload)) from lastcallers where stealth=0 group by bbsname order by sum(convert(bigint, upload)) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopCallers:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,convert(bigint, count(*)) from lastcallers group by username order by count(*) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopBBSCalls:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,convert(bigint, count(*)) from lastcallers where stealth=0 group by bbsname order by count(*) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopDownloaders:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,sum(convert(bigint, download)) from lastcallers group by username order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopBBSDownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,sum(convert(bigint, download)) from lastcallers where stealth=0 group by bbsname order by sum(convert(bigint, download)) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopUserCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " username,convert(bigint, max(topcps)) from lastcallers group by username order by max(topcps) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.alltimeTopBBSCps:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbsname,convert(bigint, max(topcps)) from lastcallers where stealth=0 group by bbsname order by max(topcps) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
                        break;
                    }
                case StatType.weektopBBSuploadsAmigaOnly:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbs.bbsname,sum(convert(bigint, confuploads.upload)) from lastcallers,confuploads,bbs where confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and stealth=0 and confuploads.upload > 0 group by bbs.bbsname order by sum(convert(bigint, confuploads.upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbs.bbsname from lastcallers,confuploads,bbs where stealth=0 and confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 and confuploads.upload > 0", sqlConn); break;
                    }

                case StatType.monthtopBBSuploadsAmigaOnly:
                    {

                        sqlCmd = new SqlCommand("select top " + count.ToString() + " bbs.bbsname,sum(convert(bigint,  confuploads.upload)) from lastcallers,confuploads,bbs where confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and stealth=0 and confuploads.upload > 0 group by bbs.bbsname order by sum(convert(bigint, confuploads.upload)) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbs.bbsname from lastcallers,confuploads,bbs where stealth=0 and confuploads.callerid=lastcallers.id and bbs.bbsname=lastcallers.bbsname and confuploads.confid=bbs.amigaconfid and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 and confuploads.upload > 0", sqlConn);
                        break;
                    }
                case StatType.weektopFileDownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " filename,convert(bigint,count(*)) from lastcallers inner join calldownloadfiles cdf on cdf.callerid=lastcallers.id where convert(date,dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1 group by filename order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getWeekDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and (dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1", sqlConn);
                        break;
                    }
                case StatType.monthtopFileDownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " filename,convert(bigint,count(*)) from lastcallers inner join calldownloadfiles cdf on cdf.callerid=lastcallers.id where convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1 group by filename order by count(*) desc", sqlConn);
                        sqlCmd2 = new SqlCommand(getMonthDaysSql(offset), sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1", sqlConn);
                        break;
                    }
                case StatType.alltimeFileDownloads:
                    {
                        sqlCmd = new SqlCommand("select top " + count.ToString() + " filename,convert(bigint,count(*)) from lastcallers  inner join calldownloadfiles cdf on cdf.callerid=lastcallers.id  group by filename order by count(*) desc", sqlConn);
                        sqlCmd3 = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);
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
                        stats.Add(sqlData.GetString(0), sqlData.GetInt64(1));
                    }
                }
                finally
                {
                    sqlData.Close();
                    sqlData.Dispose();
                    sqlCmd.Dispose();
                }
            }

            if (sqlCmd2 != null)
            {
                if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
                SqlDataReader sqlData = sqlCmd2.ExecuteReader();
                try
                {
                    if (sqlData.Read())
                    {
                        stats.currentDay = sqlData.GetInt32(0);
                        stats.dayCount = sqlData.GetInt32(1);
                        stats.endDate = sqlData.GetString(2);
                    }
                }
                finally
                {
                    sqlData.Close();
                    sqlData.Dispose();
                    sqlCmd2.Dispose();
                }
            }

            if (sqlCmd3 != null)
            {
                if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
                SqlDataReader sqlData = sqlCmd3.ExecuteReader();
                try
                {
                    while (sqlData.Read())
                    {
                        stats.bbs.Add(sqlData.GetString(0));
                    }
                }
                finally
                {
                    sqlData.Close();
                    sqlData.Dispose();
                    sqlCmd3.Dispose();
                }
            }
            return Ok(stats);
        }

        [HttpGet]
        [Route("")]
        // GET: api/GlobalLastCallers
        public IHttpActionResult GetLastCalls([FromUri] int count = 10, [FromUri] int start = 1, [FromUri] string tzname = null, [FromUri] string bbsname = null, [FromUri] string username = null)
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

            StringBuilder sqlText = new StringBuilder();

            string bbsfilter = "where stealth=0";
            string bbsfilter2 = "";
            if (bbsname != null)
            {
                bbsfilter = "where stealth=0 and bbsname = '" + bbsname + "'";
                bbsfilter2 = "bbsname = '" + bbsname + "' and ";
            }

            if (username!=null)
            {
                bbsfilter = bbsfilter + " and username = '" + username + "'";
                bbsfilter2 = bbsfilter2 + "username = '" + username + "' and ";
            }

            if (tzMins != null)
                sqlText.Append("select * from " +
                "(select Top " + (start + count - 1).ToString() + " ROW_NUMBER() over(order by dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)) desc) as rn, " +
                "id, username, bbsname, location, " +
                "convert(varchar, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)), 105) as dateon, " +
                "substring(convert(char, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, convert(time, timeon)), 8), 1, 5) timeon, " +
                "case when timeoff='--:--' then timeoff else substring(convert(char, dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, convert(time, timeoff)), 8), 1, 5) end timeoff, " +
                "actions, upload, download from LastCallers " +bbsfilter+
                " order by dateadd(mi,case when tzoffset is null then 0 else -tzoffset + " + tzMins.ToString() + " end, dateon + convert(datetime, timeon)) desc,id desc) s where s.rn >= " + start.ToString());
            else
                sqlText.Append("select * from (select Top " + (start + count - 1).ToString() + " ROW_NUMBER() over(order by lastCallers.dateon desc,lastCallers.timeon desc) as rn,id,username,bbsname,location,convert(varchar,dateon,105) as dateon,timeon,timeoff,actions,upload,download from LastCallers "+bbsfilter+" order by lastCallers.dateon desc,lastCallers.timeon desc,id desc) s where s.rn>=" + start.ToString());

            sqlCmd = new SqlCommand(sqlText.ToString(),sqlConn);

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

            SqlCommand sqlCmd2 = new SqlCommand("select 1 as rid, convert(varchar,getdate() - 1,5) as statdate, count(*) as calls, isnull(sum(convert(bigint,upload)),0) as upload, isnull(sum(convert(bigint,download)),0) as download, isnull(max(topcps),0) as topcps from lastcallers where "+bbsfilter2+"dateon = convert(date, getdate() - 1) union all select 2 as rid, convert(varchar,getdate() - 2,5) as statdate, count(*) as calls, isnull(sum(convert(bigint,upload)),0) as upload, isnull(sum(convert(bigint,download)),0) as download, isnull(max(topcps),0) as topcps from lastcallers where "+bbsfilter2+" dateon = convert(date, getdate() - 2) order by rid", sqlConn);
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

            SqlCommand sqlCmd3 = new SqlCommand("select count(*) as allcalls from lastCallers "+bbsfilter, sqlConn);
            try
            {
                stats.records.allcalls = (int)sqlCmd3.ExecuteScalar();
            }
            finally
            {
                sqlCmd3.Dispose();
            }


            SqlCommand sqlCmd4 = new SqlCommand("select top 3 bbsname,count(*) as subcount from lastCallers "+bbsfilter+" group by bbsname order by count(*) desc", sqlConn);
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

            SqlCommand sqlCmd5 = new SqlCommand("select top 1 count(*) as allcalls from lastCallers "+bbsfilter+" group by dateon order by allcalls desc", sqlConn);
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
        [Route("")]
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


            if (newCaller.Stealth == null) newCaller.Stealth = false;

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
                SqlCommand sqlCmd = new SqlCommand("insert into LastCallers (username,location,bbsname,dateon,timeon,timeoff,actions,upload,download,topcps,tzoffset,stealth) values (@username,@location,@bbsname,@dateon,@timeon,@timeoff,@actions,@upload,@download,@topcps,@tzoffset,@stealth) SELECT CAST(scope_identity() AS int);", sqlConn);
                sqlCmd.Parameters.Add("username", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("location", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("bbsname", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("dateon", SqlDbType.Date);
                sqlCmd.Parameters.Add("timeon", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("timeoff", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("actions", SqlDbType.VarChar);
                sqlCmd.Parameters.Add("upload", SqlDbType.Int);
                sqlCmd.Parameters.Add("download", SqlDbType.Int);
                sqlCmd.Parameters.Add("topcps", SqlDbType.Int);
                sqlCmd.Parameters.Add("tzoffset", SqlDbType.Int);
                sqlCmd.Parameters.Add("stealth", SqlDbType.Bit);

                sqlCmd.Parameters["username"].Value = newCaller.Username;

                if ((newCaller.Location != null) && (newCaller.Location!=String.Empty))
                    sqlCmd.Parameters["location"].Value = newCaller.Location;
                else
                    sqlCmd.Parameters["location"].Value = DBNull.Value;

                sqlCmd.Parameters["bbsname"].Value = newCaller.Bbsname;
                sqlCmd.Parameters["dateon"].Value = dateOn;
                sqlCmd.Parameters["timeon"].Value = newCaller.Timeon;
                sqlCmd.Parameters["timeoff"].Value = newCaller.Timeoff;
                sqlCmd.Parameters["actions"].Value = newCaller.Actions;
                sqlCmd.Parameters["upload"].Value = newCaller.Upload;
                sqlCmd.Parameters["download"].Value = newCaller.Download;
                sqlCmd.Parameters["topcps"].Value = newCaller.TopCps;
                sqlCmd.Parameters["stealth"].Value = newCaller.Stealth;
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
                SqlCommand sqlUpdateCmd = new SqlCommand("update LastCallers set location=@location, actions=@actions, upload=@upload, download=@download, topcps=@topcps, tzoffset=@tzoffset, stealth=@stealth where id = @id", sqlConn);
                sqlUpdateCmd.Parameters.Add("location", SqlDbType.VarChar);
                sqlUpdateCmd.Parameters.Add("actions", SqlDbType.VarChar);
                sqlUpdateCmd.Parameters.Add("upload", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("download", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("topcps", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("tzoffset", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("id", SqlDbType.Int);
                sqlUpdateCmd.Parameters.Add("stealth", SqlDbType.Bit);

                sqlUpdateCmd.Parameters["actions"].Value = newCaller.Actions;
                sqlUpdateCmd.Parameters["upload"].Value = newCaller.Upload;
                sqlUpdateCmd.Parameters["download"].Value = newCaller.Download;
                sqlUpdateCmd.Parameters["topcps"].Value = newCaller.TopCps;
                sqlUpdateCmd.Parameters["stealth"].Value = newCaller.Stealth;
                sqlUpdateCmd.Parameters["id"].Value = existingId;
                if (tzMins != null)
                    sqlUpdateCmd.Parameters["tzoffset"].Value = tzMins;
                else
                    sqlUpdateCmd.Parameters["tzoffset"].Value = DBNull.Value;
                sqlUpdateCmd.CommandTimeout = 60;

                if ((newCaller.Location != null) && (newCaller.Location != String.Empty))
                    sqlUpdateCmd.Parameters["location"].Value = newCaller.Location;
                else
                    sqlUpdateCmd.Parameters["location"].Value = DBNull.Value;

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

            if ((newCaller.ConfNums != null) && (newCaller.ConfUploads != null)) {
                SqlCommand sqlConfUploadsDel = new SqlCommand("delete from confuploads where callerid = @callerid", sqlConn);
                sqlConfUploadsDel.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfUploadsDel.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    sqlConfUploadsDel.ExecuteNonQuery();
                }
                finally
                {
                    sqlConfUploadsDel.Dispose();
                }

                SqlCommand sqlConfUploadsIns = new SqlCommand("insert into confuploads (callerid, confid, upload) values(@callerid,@confid,@upload)", sqlConn);
                sqlConfUploadsIns.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfUploadsIns.Parameters.Add("confid", SqlDbType.Int);
                sqlConfUploadsIns.Parameters.Add("upload", SqlDbType.Int);
                sqlConfUploadsIns.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    for (int i = 0; i < newCaller.ConfNums.Count; i++)
                    {
                        sqlConfUploadsIns.Parameters["confid"].Value = newCaller.ConfNums[i];
                        sqlConfUploadsIns.Parameters["upload"].Value = newCaller.ConfUploads[i];
                        sqlConfUploadsIns.ExecuteNonQuery();
                    }
                }
                finally
                {
                    sqlConfUploadsIns.Dispose();
                }
            }

            if (newCaller.UploadFiles != null)
            {
                SqlCommand sqlConfUploadsDel = new SqlCommand("delete from calluploadfiles where callerid = @callerid", sqlConn);
                sqlConfUploadsDel.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfUploadsDel.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    sqlConfUploadsDel.ExecuteNonQuery();
                }
                finally
                {
                    sqlConfUploadsDel.Dispose();
                }

                SqlCommand sqlConfUploadsIns = new SqlCommand("insert into calluploadfiles (callerid, filename) values(@callerid,@filename)", sqlConn);
                sqlConfUploadsIns.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfUploadsIns.Parameters.Add("filename", SqlDbType.VarChar);
                sqlConfUploadsIns.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    for (int i = 0; i < newCaller.UploadFiles.Count; i++)
                    {
                        sqlConfUploadsIns.Parameters["filename"].Value = newCaller.UploadFiles[i];
                        sqlConfUploadsIns.ExecuteNonQuery();
                    }
                }
                finally
                {
                    sqlConfUploadsIns.Dispose();
                }
            }

            if (newCaller.DownloadFiles != null)
            {
                SqlCommand sqlConfDownloadsDel = new SqlCommand("delete from calldownloadfiles where callerid = @callerid", sqlConn);
                sqlConfDownloadsDel.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfDownloadsDel.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    sqlConfDownloadsDel.ExecuteNonQuery();
                }
                finally
                {
                    sqlConfDownloadsDel.Dispose();
                }

                SqlCommand sqlConfDownloadsIns = new SqlCommand("insert into calldownloadfiles (callerid, filename) values(@callerid,@filename)", sqlConn);
                sqlConfDownloadsIns.Parameters.Add("callerid", SqlDbType.Int);
                sqlConfDownloadsIns.Parameters.Add("filename", SqlDbType.VarChar);
                sqlConfDownloadsIns.Parameters["callerid"].Value = newCaller.Id;
                try
                {
                    for (int i = 0; i < newCaller.DownloadFiles.Count; i++)
                    {
                        sqlConfDownloadsIns.Parameters["filename"].Value = newCaller.DownloadFiles[i];
                        sqlConfDownloadsIns.ExecuteNonQuery();
                    }
                }
                finally
                {
                    sqlConfDownloadsIns.Dispose();
                }
            }

            return Ok(newCaller);
        }

        [HttpGet]
        [Route("bbslist")]
        [ResponseType(typeof(List<string>))]
        // GET: api/GlobalLastCallers/bbslist
        public IHttpActionResult GetBBSNames()
        {
            List<string> bbsList = new List<string>();

            SqlCommand sqlCmd = new SqlCommand("select distinct bbsname from lastcallers where stealth=0", sqlConn);

            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                while (sqlData.Read())
                {
                    bbsList.Add(sqlData.GetString(0));
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }
            return Ok(bbsList);
        }

        [HttpGet]
        [Route("recentfiles")]
        [ResponseType(typeof(List<string>))]
        // GET: api/GlobalLastCallers/recentfiles
        public IHttpActionResult GetRecentFiles([FromUri] bool months = false, [FromUri] int offset = 0, [FromUri] string bbsname = null, [FromUri] string username = null)
        {
            List<string> recentFiles = new List<string>();

            SqlCommand sqlCmd;

            string bbsfilter = "";
            if (bbsname != null) bbsfilter = " and bbsname = '" + bbsname + "'";

            if (username !=null) bbsfilter = bbsfilter+ " and username = '" + username + "'";

            if (!months)
                sqlCmd = new SqlCommand("select filename from lastcallers inner join calluploadfiles cuf on cuf.callerid=lastcallers.id where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(wk,-" + offset.ToString() + ",(cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) and(dateadd(wk, -" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - ((datepart(dw, getdate())) - 1))) + 7) - 1" + bbsfilter + " order by convert(datetime, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon)))", sqlConn);
            else
                sqlCmd = new SqlCommand("select filename from lastcallers inner join calluploadfiles cuf on cuf.callerid=lastcallers.id where stealth=0 and convert(date, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon))) between dateadd(m,0-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1))) and dateadd(m,1-" + offset.ToString() + ", (cast(CAST(GETDATE() as date) as datetime) - (datepart(d, getdate()) - 1)))-1" + bbsfilter + " order by convert(datetime, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon)))", sqlConn);


            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                while (sqlData.Read())
                {
                    if (recentFiles.IndexOf(sqlData.GetString(0)) == -1) recentFiles.Add(sqlData.GetString(0));
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }
            return Ok(recentFiles);
        }

        [HttpGet]
        [Route("fileinfo")]
        [ResponseType(typeof(Dictionary<string,string>))]
        // GET: api/GlobalLastCallers/fileinfo
        public IHttpActionResult fileInfo([FromUri] string filename)
        {
            List<FileDetails> bbslist = new List<FileDetails>();
            List<string> templist = new List<string>();

            SqlCommand sqlCmd;
            sqlCmd = new SqlCommand("select bbsname, convert(varchar, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon)),113), username from lastcallers inner join calluploadfiles cuf on cuf.callerid=lastcallers.id where stealth=0 and filename = @filename order by convert(datetime, dateadd(mi,case when tzoffset is null then 0 else -tzoffset end, dateon + convert(datetime, timeon)))", sqlConn);
            sqlCmd.Parameters.Add("filename", SqlDbType.VarChar);
            sqlCmd.Parameters["filename"].Value = filename;

            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();
            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                while (sqlData.Read())
                {
                    FileDetails f = new FileDetails();
                    f.bbsname = sqlData.GetString(0);
                    f.calldate = sqlData.GetString(1);
                    f.calluser = sqlData.GetString(2);

                    if (templist.Contains(f.bbsname) == false)
                    {
                        bbslist.Add(f);
                        templist.Add(f.bbsname);
                    }
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }
            return Ok(bbslist);
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
