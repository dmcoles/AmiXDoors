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
    [RoutePrefix("api/DailyFileDiz")]
    public class FileDizController : ApiController
    {
        SqlConnection sqlConn = new SqlConnection(ConfigurationManager.ConnectionStrings["WallDb"].ConnectionString);

        private FileDiz ReadDailyItem()
        {
            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd = new SqlCommand("select id,diztext,format(getdate(),'dd-MMM-yyyy') dizDate from filediz where id = (((select max(v) from (values (datediff(d,'2018/12/20 00:00',getdate())),(0)) as value(v)) % (select count(*) from filediz))+1)", sqlConn);
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

        private FileDiz ReadItem(SqlDataReader sqlData)
        {
            FileDiz fileDizItem = new FileDiz();
            fileDizItem.Id = (int)sqlData["id"];
            fileDizItem.fileDizText = (string)sqlData["dizText"];
            fileDizItem.fileDizDate = (string)sqlData["dizDate"];
            return fileDizItem;
        }

        [HttpGet]
        [Route("")]
        [DisableCacheClient]
        // GET: api/FileDiz
        public IHttpActionResult GetFileDiz()
        {
            try
            {
                Console.WriteLine("Get daily diz request: " + DateTime.UtcNow);
                FileDiz w = ReadDailyItem();
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