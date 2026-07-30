import { Injectable } from '@nestjs/common';
import * as AWS from 'aws-sdk';

@Injectable()
export class AuditService {
  private dynamoDb = new AWS.DynamoDB.DocumentClient({ region: 'af-south-1' });
  private tableName = 'OmniBus_Admin_Audit_Ledger';

  async getLogs(adminId?: string, action?: string, from?: string, to?: string): Promise<any[]> {
    const params: any = {
      TableName: this.tableName,
      Limit: 100,
    };

    if (adminId) {
      params.KeyConditionExpression = 'ADMIN_ID = :adminId';
      params.ExpressionAttributeValues = { ':adminId': adminId };
    }

    const result = await this.dynamoDb.query(params).promise();
    return result.Items || [];
  }

  async logAction(adminId: string, actionType: string, resource: string, changes: any, ip: string): Promise<void> {
    const timestamp = new Date().toISOString();
    const item = {
      ADMIN_ID: adminId,
      TIMESTAMP_ACTION_ID: `${timestamp}#${Date.now()}`,
      ActionType: actionType,
      ResourceTarget: resource,
      IPAddress: ip,
      ChangesApplied: JSON.stringify(changes),
      CryptographicSignature: 'signed-hash-placeholder',
    };
    await this.dynamoDb.put({ TableName: this.tableName, Item: item }).promise();
  }
}
