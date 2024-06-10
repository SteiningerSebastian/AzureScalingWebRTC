using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography.Xml;
using System.Text;
using System.Threading.Tasks;

namespace ChatFunctionApp {
    public class StatisticsRepo : IStatisticsRepo {
        private const string CREATE_TABLE_STATEMENT = @"
        CREATE TABLE MessageStatistics (
            MessageDate DATE,
            nMessages INT,
            PRIMARY KEY (MessageDate)
        );";

        private const string UPDATE_STATEMENT = @"
        BEGIN TRAN
        IF EXISTS (SELECT * FROM MessageStatistics WITH (UPDLOCK, SERIALIZABLE) WHERE MessageDate = @dateParam)
            BEGIN
                UPDATE MessageStatistics
                SET nMessages = nMessages + 1
                WHERE MessageDate = @dateParam
            END
        ELSE
            BEGIN
                INSERT INTO MessageStatistics (MessageDate, nMessages)
                VALUES (@dateParam, 1)
            END
        COMMIT TRAN";

        private const string SELECT_STATS_STATEMENT = @"
        SELECT 
            (SELECT MAX(nMessages) 
            FROM MessageStatistics
            WHERE MessageDate = @dateParam),
            (SELECT SUM(nMessages) 
            FROM MessageStatistics)";

        public SqlConnection Connection { get; private set; }

        public StatisticsRepo() {
            var str = Environment.GetEnvironmentVariable("sqldb_connection");
            Connection = new(str);
        }

        public async Task<StatisticsUpdateMessage> GetStatisticsUpdateMessage() {
            if (Connection.State == System.Data.ConnectionState.Closed)
                await Connection.OpenAsync();

            int today = 0;
            int sum = 0;
            SqlCommand command = new SqlCommand(SELECT_STATS_STATEMENT, Connection);
            command.Parameters.AddWithValue("@dateParam", DateTime.UtcNow.Date);
            using (SqlDataReader reader = command.ExecuteReader()) {
                // Check if there are any results
                if (reader.HasRows) {
                    // Loop through each row
                    while (reader.Read()) {
                        today = reader.GetInt32(0);
                        sum = reader.GetInt32(1);
                    }
                }
            }

            return new StatisticsUpdateMessage() { Messages = sum, MessagesToday = today };
        }

        public async Task MessageSent() {
            if (Connection.State == System.Data.ConnectionState.Closed)
                await Connection.OpenAsync();


            SqlCommand cmd = new SqlCommand(UPDATE_STATEMENT, Connection);
            cmd.Parameters.AddWithValue("@dateParam", DateTime.UtcNow.Date);
            cmd.ExecuteNonQuery();
        }

        public async Task EnsureTable() {
            if (Connection.State == System.Data.ConnectionState.Closed)
                await Connection.OpenAsync();

            SqlCommand command = new SqlCommand(CREATE_TABLE_STATEMENT, Connection);
            command.ExecuteNonQuery();
        }

        public void Dispose() {
            Connection.Close();
            Connection.Dispose();
        }
    }
}
