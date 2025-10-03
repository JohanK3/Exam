// src/app/services/answer.service.ts
import { Injectable } from '@angular/core';
import { CommonService } from './common.service';
import { environment } from 'src/environments/environment';
import { Answer } from '../models/Answer';

@Injectable({
  providedIn: 'root'
})
export class AnswerService extends CommonService<Answer> {

  // Le endpoint de base est désormais construit avec le préfixe "/api"
  protected baseEnpoint = `${environment.API_URL}/answers`;

  constructor(http: HttpClient) {
    super(http);
  }
}