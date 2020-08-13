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
    [RoutePrefix("api/WallItems")]
    public class WallItemsController : ApiController
    {
        SqlConnection sqlConn = new SqlConnection(ConfigurationManager.ConnectionStrings["WallDb"].ConnectionString);

        private void DeleteItem(int id)
        {
            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd = new SqlCommand("delete from wallitems where id = (select top 1 id from wallitems where id = @id order by id asc)", sqlConn);
            sqlCmd.Parameters.Add("id", SqlDbType.Int);
            sqlCmd.Parameters["id"].Value = id;
            try
            {
                sqlCmd.ExecuteNonQuery();
            }
            finally
            {
                sqlCmd.Dispose();
            }
        }

        private WallItem ReadItem(int id)
        {
            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd = new SqlCommand("select top 1 * from wallitems where id = @id order by id asc", sqlConn);
            sqlCmd.Parameters.Add("id", SqlDbType.Int);
            sqlCmd.Parameters["id"].Value = id;
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

        private WallItem ReadItem(SqlDataReader sqlData)
        {
            WallItem wallItem = new WallItem();
            wallItem.Id = (int)sqlData["id"];
            wallItem.source = (string)sqlData["source"];
            wallItem.userName = (string)sqlData["username"];
            wallItem.comment = (string)sqlData["comment"];
            wallItem.bbsshortcode = (string) sqlData["bbsshortcode"];
            wallItem.createdDate = (DateTimeOffset)sqlData["createddate"];
            return wallItem;
        }

        [HttpGet]
        [Route("")]
        [DisableCacheClient]
        // GET: api/WallItems
        public IEnumerable<WallItem> GetWallItems([FromUri] int itemCount = 25, [FromUri] int pageNum = 1 )
        {
            Console.WriteLine("Get all items request: " + DateTime.UtcNow);

            if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

            SqlCommand sqlCmd = new SqlCommand("select * from (select * from wallitems order by id desc offset "+(pageNum-1)*itemCount+"rows fetch next "+itemCount+" rows only) w order by w.id asc", sqlConn);
            List<WallItem> items = new List<WallItem>();
            SqlDataReader sqlData = sqlCmd.ExecuteReader();
            try
            {
                while (sqlData.Read())
                {
                    items.Add(ReadItem(sqlData));
                }
            }
            finally
            {
                sqlData.Close();
                sqlData.Dispose();
                sqlCmd.Dispose();
            }

            return items;

        }

        [HttpGet]
        [Route("{id}")]
        [DisableCacheClient]
        // GET: api/WallItems/{id}
        public IHttpActionResult GetWallItem(int id, [FromUri] bool ping = false)
        {
            if (!ping) Console.WriteLine($"Get single item ({id}) request: " + DateTime.UtcNow);
            try
            {
                WallItem w = ReadItem(id);
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


        [HttpPost]
        [Route("")]
        // POST: api/WallItems
        [ResponseType(typeof(WallItem))]
        public IHttpActionResult PostWallItem(WallItem wallItem)
        {
            Console.WriteLine($"Post item request: " + DateTime.UtcNow);
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(ModelState);
                }

                if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

                SqlCommand sqlCmd = new SqlCommand("insert into wallitems (username, source, comment, bbsshortcode, createdDate) values (@username, @source, @comment, @bbsshortcode, @createddate); SELECT CAST(scope_identity() AS int);", sqlConn);
                sqlCmd.Parameters.Add("username", SqlDbType.VarChar);
                sqlCmd.Parameters["username"].Value = wallItem.userName;

                sqlCmd.Parameters.Add("source", SqlDbType.VarChar);
                sqlCmd.Parameters["source"].Value = wallItem.source;

                sqlCmd.Parameters.Add("comment", SqlDbType.VarChar);
                sqlCmd.Parameters["comment"].Value = wallItem.comment;

                sqlCmd.Parameters.Add("bbsshortcode", SqlDbType.VarChar);
                sqlCmd.Parameters["bbsshortcode"].Value = wallItem.bbsshortcode;

                sqlCmd.Parameters.Add("createdDate", SqlDbType.DateTimeOffset);
                sqlCmd.Parameters["createdDate"].Value = DateTimeOffset.Now;

                try
                {
                    wallItem.Id = (int) sqlCmd.ExecuteScalar();
                }
                finally
                {
                    sqlCmd.Dispose();
                }

                return Ok(wallItem);
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }
        }

        [HttpPut]
        [Route("{id}")]
        // PUT: api/WallItems
        [ResponseType(typeof(WallItem))]
        public IHttpActionResult PutWallItem(int id, WallItem wallItem)
        {
            Console.WriteLine($"Put item ({id}) request: " + DateTime.UtcNow);
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(ModelState);
                }

                if (wallItem.userName != null || wallItem.source != null || wallItem.comment != null || wallItem.bbsshortcode != null)
                {

                    if (sqlConn.State != ConnectionState.Open) sqlConn.Open();

                    StringBuilder sqltext = new StringBuilder("update wallitems set");

                    if (wallItem.userName != null)
                    {
                        sqltext.Append(" username = @username,");
                    }

                    if (wallItem.source != null)
                    {
                        sqltext.Append(" source = @source,");
                    }

                    if (wallItem.comment != null)
                    {
                        sqltext.Append(" comment = @comment,");
                    }

                    if (wallItem.bbsshortcode != null)
                    {
                        sqltext.Append(" bbsshortcode = @bbsshortcode,");
                    }

                    sqltext.Remove(sqltext.Length - 1, 1);

                    sqltext.Append(" where id = @id");

                    SqlCommand sqlCmd =
                        new SqlCommand(sqltext.ToString(),sqlConn);

                    if (wallItem.userName != null)
                    {
                        sqlCmd.Parameters.Add("username", SqlDbType.VarChar);
                        sqlCmd.Parameters["username"].Value = wallItem.userName;
                    }

                    if (wallItem.source != null)
                    {
                        sqlCmd.Parameters.Add("source", SqlDbType.VarChar);
                        sqlCmd.Parameters["source"].Value = wallItem.source;
                    }

                    if (wallItem.comment != null)
                    {
                        sqlCmd.Parameters.Add("comment", SqlDbType.VarChar);
                        sqlCmd.Parameters["comment"].Value = wallItem.comment;
                    }

                    if (wallItem.bbsshortcode != null)
                    {
                        sqlCmd.Parameters.Add("bbsshortcode", SqlDbType.VarChar);
                        sqlCmd.Parameters["bbsshortcode"].Value = wallItem.bbsshortcode;
                    }

                    sqlCmd.Parameters.Add("id", SqlDbType.Int);
                    sqlCmd.Parameters["id"].Value = id;

                    sqlCmd.ExecuteNonQuery();
                }

                return Ok(ReadItem(id));
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }
        }

        [HttpDelete]
        [Route("{id}")]
        // DELETE: api/WallItems/5
        [ResponseType(typeof(WallItem))]
        public IHttpActionResult DeleteWallItem(int id)
        {
            Console.WriteLine($"Delete item ({id}) request: " + DateTime.UtcNow);
            try
            {
                WallItem wallItem = ReadItem(id);
                if (wallItem == null)
                {
                    return NotFound();
                }

                DeleteItem(id);

                return Ok(wallItem);
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