// src/app/services/course.service.ts
import { Injectable } from '@angular/core';
import { CommonService } from './common.service';
import { Course } from '../models/Course';
import { environment } from 'src/environments/environment';
import { HttpClient } from '@angular/common/http';

@Injectable({
  providedIn: 'root'
})
export class CourseService extends CommonService<Course> {
  // Le endpoint de base est désormais construit avec le préfixe "/api"
  protected baseEnpoint = `${environment.API_URL}/courses`;
}
