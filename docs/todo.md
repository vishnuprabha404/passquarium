# Passquarium - TODO & Improvements

## [System Date: 2025-06-19 22:22]

### Performance Issues
- [ ] Review startup time - Firebase initialization could be optimized
- [ ] Check memory usage during password operations
- [ ] Optimize build size - 18 outdated dependencies

### UI/UX Polish  
- [ ] Debug banner already disabled ✅
- [ ] Review user flow from Device Auth → Email Auth → Master Key → Dashboard
- [ ] Check for consistent theming across all screens

### Features to Add Next
- [ ] Implement missing AuthService methods (hasMasterPassword, setMasterPassword)
- [ ] Add comprehensive error handling for Firebase Auth operations
- [ ] Consider adding export/import functionality
- [ ] Add password sharing capabilities

### Technical Debt
- [ ] Fix 88 code style violations (curly braces in flow control)
- [ ] Update 18 outdated dependencies safely
- [ ] Add comprehensive unit tests
- [ ] Implement proper logging service
- [ ] Review and optimize encryption performance
- [ ] Add comprehensive error boundary handling

### Security Enhancements
- [ ] Review Firebase Auth configuration 
- [ ] Audit all encryption implementations
- [ ] Add rate limiting for authentication attempts
- [ ] Implement secure key derivation validation

### Documentation
- [ ] Update README with latest features
- [ ] Create API documentation for services
- [ ] Add troubleshooting guide for common issues 