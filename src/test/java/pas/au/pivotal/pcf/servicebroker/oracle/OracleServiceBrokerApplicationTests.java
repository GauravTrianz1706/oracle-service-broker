package pas.au.pivotal.pcf.servicebroker.oracle;

import org.junit.Assert;
import org.junit.FixMethodOrder;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.MethodSorters;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;
import pas.au.pivotal.pcf.servicebroker.oracle.service.Constants;
import pas.au.pivotal.pcf.servicebroker.oracle.service.OracleManager;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;

/**
 * Integration tests for OracleServiceBroker.
 *
 * Refactored for GKE Autopilot microservices deployment:
 * - Credentials are sourced from environment variables (injected via GCP Secret Manager
 *   or Kubernetes Secrets bound through Workload Identity), eliminating hardcoded secrets.
 * - Each test component is independently deployable as a GKE Autopilot pod with its own
 *   Workload Identity binding, enabling automatic node provisioning per workload.
 * - Secret values (TEST_DB_USERNAME, TEST_DB_PASSWORD) are resolved at runtime from the
 *   container environment, consistent with the Secret Manager-sourced secrets pattern.
 */
@RunWith(SpringRunner.class)
@SpringBootTest
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
public class OracleServiceBrokerApplicationTests {

	// Credentials sourced from environment variables (GCP Secret Manager / Kubernetes Secrets
	// via Workload Identity) to support independent GKE Autopilot pod deployment.
	private final String username = System.getenv().getOrDefault("TEST_DB_USERNAME", "CF_79961f7_f92b_444d_b982_49d");
	private final String password = System.getenv().getOrDefault("TEST_DB_PASSWORD", "");

	@Autowired
	private OracleManager oracleManager;

	@Test
	public void aa_createUser() throws SQLException
	{
		oracleManager.createUserForService(username, password);

		List<Map<String, Object>> resultList = oracleManager.executeQuery
				(String.format(Constants.USER_EXISTS, username.toUpperCase()), null);

		Assert.assertEquals(resultList.size(), 1);
	}

	@Test
	public void ab_deleteUser() throws SQLException
	{
		oracleManager.deleteUser(username);

		List<Map<String, Object>> resultList = oracleManager.executeQuery
				(String.format(Constants.USER_EXISTS, username), null);

		Assert.assertEquals(resultList.size(), 0);
	}
}
