package pas.au.pivotal.pcf.servicebroker.oracle.model;

import javax.persistence.*;
import java.util.Set;

@Entity
@Table (name = "si_binding")
public class ServiceInstanceBinding
{
    @Id
    @Column (name = "binding_id")
    private String bindingid;

    @Column (name = "service_binding_id")
    private String serviceInstanceId;

    private String syslogDrainUrl;
    private String appGuid;

    public ServiceInstanceBinding() {
    }

    public String getBindingid() {
        return bindingid;
    }

    public void setBindingid(String bindingid) {
        this.bindingid = bindingid;
    }

    public String getServiceInstanceId() {
        return serviceInstanceId;
    }

    public void setServiceInstanceId(String serviceInstanceId) {
        this.serviceInstanceId = serviceInstanceId;
    }

    public String getSyslogDrainUrl() {
        return syslogDrainUrl;
    }

    public void setSyslogDrainUrl(String syslogDrainUrl) {
        this.syslogDrainUrl = syslogDrainUrl;
    }

    public String getAppGuid() {
        return appGuid;
    }

    public void setAppGuid(String appGuid) {
        this.appGuid = appGuid;
    }

    @Override
    public String toString() {
        return "ServiceInstanceBinding{" +
                "bindingid='" + bindingid + '\'' +
                ", serviceInstanceId='" + serviceInstanceId + '\'' +
                ", syslogDrainUrl='" + syslogDrainUrl + '\'' +
                ", appGuid='" + appGuid + '\'' +
                '}';
    }
}
