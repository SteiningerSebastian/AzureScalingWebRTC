using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ChatFunctionApp {
    public interface IStatisticsRepo: IDisposable {
        public Task MessageSent();
        public Task<StatisticsUpdateMessage> GetStatisticsUpdateMessage();
    }
}
