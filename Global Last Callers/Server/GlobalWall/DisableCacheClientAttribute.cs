using System;
using System.Net.Http.Headers;
using System.Web.Http.Filters;

namespace GlobalWall
{
    public class DisableCacheClientAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuted(HttpActionExecutedContext actionExecutedContext)
        {
            if (actionExecutedContext.Response != null)
            {
                actionExecutedContext.Response.Headers.CacheControl = new CacheControlHeaderValue
                {
                    MaxAge = TimeSpan.FromSeconds(1),
                    NoCache = true,
                };
            }
        }
    }
}
