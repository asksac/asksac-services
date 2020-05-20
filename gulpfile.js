'use strict'

const gulp = require('gulp');
const del = require('del'); 
const gulpInstall = require('gulp-install'); 
const gulpZip = require('gulp-zip'); 

const path = require('path');

class LambdaPacker {
  lname = ''; // directory name of this Lambda function 
  srcBasePath = 'src'; // base directory path where this Lamda function resides
  distBasePath = 'dist'; // base directory path where distribution binaries will reside

  constructor(lname, srcBasePath, distBasePath) {
    this.lname = lname; 
    this.srcBasePath = srcBasePath; 
    this.distBasePath = distBasePath; 
  }

  // copies all source js files incl package.json to a temp directory inside distBasePath
  copy = () => {
    return gulp.src(['**/*.js', 'package.json', '!gulpfile.js'], {cwd: path.join(this.srcBasePath, this.lname)})
    .pipe(gulp.dest(this.lname, {cwd: this.distBasePath})); 
  }

  // runs npm install on the copied package.json file inside the temp directory
  build = () => {
    return gulp.src('package.json', {cwd: path.join(this.distBasePath, this.lname)})
      .pipe(gulpInstall({production: true, ignoreScripts: true})); // runs npm with --production and --ignore-scripts options
  }

  // creates a zip file for Lambda deployment
  package = () => {
    return gulp.src(['**', '!package*.json', '!gulpfile.js'], {cwd: path.join(this.distBasePath, this.lname)})
      .pipe(gulpZip(this.lname + '.zip'))
      .pipe(gulp.dest(this.distBasePath)); 
  }

  // cleans up the temp directory 
  cleanup = () => {
    return del(path.join(this.distBasePath, this.lname)); 
  }

  // this factory method should be used to create a Gulp task for each Lambda function 
  static install(lname, srcBasePath, distBasePath) {
    let p = new LambdaPacker(lname, srcBasePath, distBasePath); 
    return gulp.series(p.copy, p.build, p.package, p.cleanup); 
  }
}

const installHello = LambdaPacker.install('hello', 'src/lambdas', 'dist'); 

// Combine tasks and set exports
const build = gulp.series(installHello); 

exports.build = build; 
exports.default = build; 
