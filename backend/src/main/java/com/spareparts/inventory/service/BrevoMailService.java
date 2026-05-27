package com.spareparts.inventory.service;

import brevo.ApiClient;
import brevo.ApiException;
import brevo.Configuration;
import brevo.auth.ApiKeyAuth;
import brevoModel.SendSmtpEmail;
import brevoModel.SendSmtpEmailSender;
import brevoModel.SendSmtpEmailTo;
import brevoApi.TransactionalEmailsApi;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.Collections;

@Service
@Slf4j
public class BrevoMailService {

    @Value("${brevo.api.key}")
    private String apiKey;

    @Value("${brevo.from.email}")
    private String fromEmail;

    public void sendEmail(String toEmail, String subject, String htmlContent, String plainTextContent) throws ApiException {
        ApiClient defaultClient = Configuration.getDefaultApiClient();
        ApiKeyAuth apiKeyAuth = (ApiKeyAuth) defaultClient.getAuthentication("api-key");
        apiKeyAuth.setApiKey(apiKey);

        TransactionalEmailsApi apiInstance = new TransactionalEmailsApi();

        SendSmtpEmailSender sender = new SendSmtpEmailSender();
        sender.setEmail(fromEmail);
        sender.setName("Parts Mitra");

        SendSmtpEmailTo to = new SendSmtpEmailTo();
        to.setEmail(toEmail);

        SendSmtpEmail sendSmtpEmail = new SendSmtpEmail();
        sendSmtpEmail.setSender(sender);
        sendSmtpEmail.setTo(Collections.singletonList(to));
        sendSmtpEmail.setSubject(subject);
        sendSmtpEmail.setHtmlContent(htmlContent);
        sendSmtpEmail.setTextContent(plainTextContent);

        try {
            apiInstance.sendTransacEmail(sendSmtpEmail);
            log.info("Email sent successfully to {} via Brevo API", toEmail);
        } catch (ApiException e) {
            log.error("Failed to send email to {}. Error: {}", toEmail, e.getMessage());
            throw e;
        }
    }
}
