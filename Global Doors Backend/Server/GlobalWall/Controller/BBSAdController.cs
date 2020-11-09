using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Runtime.Remoting.Messaging;
using System.Text;
using System.Web.Http;
using System.Web.Http.Description;
using System.Web.Http.Results;

namespace GlobalWall
{
    [RoutePrefix("api/BBSAd")]
    public class BBSAdController : ApiController
    {
        SqlConnection sqlConn = new SqlConnection(ConfigurationManager.ConnectionStrings["WallDb"].ConnectionString);

        private BBSAd ReadRandomItem()
        {
            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd = new SqlCommand("SELECT TOP 1 id,bbsadtext FROM bbsads ORDER BY NEWID()", sqlConn);
            List<WallItem> items = new List<WallItem>();
            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                if (sqlData.Read())
                {
                    return ReadItem(sqlData);
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }
            return null;
        }

        private BBSAd ReadItem(SqlDataReader sqlData)
        {
            BBSAd bbsAdItem = new BBSAd();
            bbsAdItem.Id = (int)sqlData["id"];
            bbsAdItem.bbsAdText= (string)sqlData["bbsAdText"];
            return bbsAdItem;
        }

        [HttpGet]
        [Route("")]
        [DisableCacheClient]
        // GET: api/BBSAd
        public IHttpActionResult GetBBSAd()
        {
            try
            {
                Console.WriteLine("Get bbs ad request: " + DateTime.UtcNow);
                BBSAd w = ReadRandomItem();
                if (w == null)
                {
                    return NotFound();
                }

                return Ok(w);
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }
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